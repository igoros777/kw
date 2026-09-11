#!/usr/bin/env python3
"""
decorrstretch.py - Decorrelation stretch via an exact per-image Karhunen-Loeve
(PCA) transform, applied with ImageMagick's -color-matrix operator.

The classic decorrelation stretch (Gillespie, Kahle & Walker 1986; the same
algorithm as MATLAB's decorrstretch) works like this:

    1. Treat every pixel as a 3-vector x = (R, G, B).
    2. Compute the mean vector mu and the 3x3 covariance matrix C of the
       pixels of THIS image (no generic "average photo" statistics).
    3. Eigendecompose C = V L V^T.  The columns of V are the principal
       components (the Karhunen-Loeve basis); L holds the variances along
       them.
    4. Rotate into the KL basis, scale each principal axis so it has unit
       variance (whitening), rotate back, then scale each RGB band to a
       target standard deviation:

           T = diag(sigma_target) . V . L^(-1/2) . V^T
           y = T (x - mu) + mu_target

       The output bands have zero mutual correlation and covariance
       diag(sigma_target^2).  With the defaults (sigma_target = the input
       band standard deviations, mu_target = mu) every band keeps its
       original mean and contrast but the colour information that was
       hidden in the tiny differences between highly correlated bands is
       spread out over the whole gamut.

The whole transform is affine, so it is expressed exactly as one ImageMagick
6x6 colour matrix:

           R'   | t00 t01 t02  0  0  oR |   R
           G'   | t10 t11 t12  0  0  oG |   G
           B' = | t20 t21 t22  0  0  oB | . B
           K'   |  0   0   0   1  0   0 |   K
           A'   |  0   0   0   0  1   0 |   A
                |  0   0   0   0  0   1 |   1

(ImageMagick puts the offset in column 6 so that CMYK and alpha fit in
columns 4 and 5; offsets are in normalised 0..1 units.)

Requirements: Python 3.8+, NumPy, ImageMagick 6 or 7 on PATH (or pass
--magick).  Pixels are read straight from ImageMagick as a 16-bit PPM stream,
so no PIL/Pillow is needed.

Examples:

    # plain decorrelation stretch, preserving band means and contrasts
    python decorrstretch.py photo.jpg photo_dcs.png

    # add a 1% linear contrast stretch per band (MATLAB 'Tol' 0.01)
    python decorrstretch.py photo.jpg photo_dcs.png --tol 0.01

    # push all bands to the same contrast (sigma in 0..1 units) and check
    # that the output really is decorrelated
    python decorrstretch.py photo.jpg out.png --sigma 0.2 --verify

    # only print the matrix for use in your own ImageMagick pipeline
    python decorrstretch.py photo.jpg --matrix-only
    magick photo.jpg -color-matrix "$(python decorrstretch.py photo.jpg --matrix-only)" out.png

    # tone down the garish greens (vegetation, lichen) the stretch produces:
    # remove 70% of the saturation of hues within +/-45 deg of green
    python decorrstretch.py photo.jpg out.png --tol 0.01 --desaturate-greens 70

Green desaturation is hue-selective, so it cannot live inside the affine
colour matrix.  It is applied by ImageMagick as a post-stage after the
matrix: a soft triangular hue mask centred on green (in HSL) blends the
stretched image with a desaturated copy of itself.
"""

import argparse
import os
import shutil
import subprocess
import sys

import numpy as np

QUANTUM_MAX = 65535.0


# --------------------------------------------------------------------------
# ImageMagick plumbing
# --------------------------------------------------------------------------
def find_magick(explicit=None):
    """Return the ImageMagick command as a list (['magick'] or ['convert'])."""
    candidates = []
    if explicit:
        candidates.append(explicit)
    if os.environ.get("MAGICK"):
        candidates.append(os.environ["MAGICK"])
    candidates += ["magick", "convert"]
    for cand in candidates:
        exe = shutil.which(cand) if not os.path.isfile(cand) else cand
        if not exe:
            continue
        try:
            out = subprocess.run([exe, "-version"], capture_output=True,
                                 text=True, timeout=30).stdout
        except (OSError, subprocess.SubprocessError):
            continue
        # On Windows 'convert' is also the NTFS filesystem tool; make sure we
        # really have ImageMagick.
        if "ImageMagick" in out:
            return [exe]
    sys.exit("error: ImageMagick not found (need 'magick' or 'convert' on "
             "PATH, or pass --magick /path/to/magick)")


def colorspace_of(linear):
    # ImageMagick names: 'sRGB' = gamma-encoded, 'RGB' = linear light.
    return "RGB" if linear else "sRGB"


def read_pixels(magick, path, linear=False):
    """
    Return an (N, 3) float64 array of RGB values in [0, 1] for every pixel
    of the (first frame of the) image, in the colourspace the matrix will
    later be applied in.  Uses a 16-bit binary PPM stream (P6), which is
    big-endian by specification.
    """
    cmd = magick + [path + "[0]", "-alpha", "off",
                    "-colorspace", colorspace_of(linear),
                    "-depth", "16", "ppm:-"]
    proc = subprocess.run(cmd, capture_output=True)
    if proc.returncode != 0:
        sys.exit("error: ImageMagick failed to read %s:\n%s"
                 % (path, proc.stderr.decode(errors="replace")))
    data = proc.stdout

    # Parse the PPM header: "P6" <ws> width <ws> height <ws> maxval <single ws>
    # (comments starting with '#' are allowed in the header).
    tokens, pos = [], 0
    while len(tokens) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            while data[pos:pos + 1] not in (b"\n", b"\r", b""):
                pos += 1
            continue
        start = pos
        while not data[pos:pos + 1].isspace():
            pos += 1
        tokens.append(data[start:pos])
    pos += 1  # exactly one whitespace byte after maxval
    if tokens[0] != b"P6":
        sys.exit("error: unexpected PPM magic %r" % tokens[0])
    width, height, maxval = int(tokens[1]), int(tokens[2]), int(tokens[3])
    dtype = ">u2" if maxval > 255 else "u1"
    pix = np.frombuffer(data, dtype=dtype, offset=pos, count=width * height * 3)
    pix = pix.reshape(height, width, 3).astype(np.float64) / maxval
    return pix.reshape(-1, 3), (width, height)


# --------------------------------------------------------------------------
# Karhunen-Loeve / decorrelation-stretch maths
# --------------------------------------------------------------------------
def parse_triplet(spec, name):
    """'auto' -> None, '0.2' -> [0.2]*3, '0.2,0.15,0.1' -> those three."""
    if spec is None or spec.lower() == "auto":
        return None
    parts = [float(p) for p in spec.split(",")]
    if len(parts) == 1:
        parts *= 3
    if len(parts) != 3:
        sys.exit("error: --%s expects 'auto', one number or three "
                 "comma-separated numbers" % name)
    return np.array(parts, dtype=np.float64)


def decorrelation_matrix(pixels, target_sigma=None, target_mean=None,
                         tol=0.0, eig_floor=1e-8):
    """
    Compute the affine decorrelation-stretch transform y = T x + offset.

    Returns (T, offset, info) where T is 3x3, offset is length-3 (both in
    normalised 0..1 units) and info is a dict with the intermediate
    statistics for reporting.
    """
    mu = pixels.mean(axis=0)
    cov = np.cov(pixels, rowvar=False)          # 3x3 sample covariance
    sigma = np.sqrt(np.diag(cov))               # per-band std dev

    # Exact KL transform of this image: eigh is the right tool for a
    # symmetric PSD matrix (returns ascending eigenvalues, orthonormal V).
    evals, evecs = np.linalg.eigh(cov)

    # Guard against a rank-deficient covariance (e.g. a grey image, or a
    # band that is constant).  Whitening such an axis would multiply pure
    # quantisation noise by a huge factor, so floor the variance.
    floored = evals < eig_floor * evals.max()
    evals_safe = np.where(floored, eig_floor * evals.max(), evals)

    if target_sigma is None:
        target_sigma = sigma
    if target_mean is None:
        target_mean = mu

    # T = diag(sigma_t) . V . L^-1/2 . V^T   (whitening, then re-colouring)
    whiten = evecs @ np.diag(1.0 / np.sqrt(evals_safe)) @ evecs.T
    T = np.diag(target_sigma) @ whiten
    offset = target_mean - T @ mu

    lo = hi = None
    if tol > 0:
        # Optional per-band linear stretch after the decorrelation, exactly
        # like MATLAB's 'Tol' option: map the [tol, 1-tol] quantiles of each
        # output band onto [0, 1].  Because the stretch is affine it folds
        # straight into T and offset.
        y = pixels @ T.T + offset
        lo = np.quantile(y, tol, axis=0)
        hi = np.quantile(y, 1.0 - tol, axis=0)
        span = np.where(hi - lo > 1e-12, hi - lo, 1.0)
        gain = 1.0 / span
        T = T * gain[:, None]
        offset = (offset - lo) * gain

    info = dict(mean=mu, cov=cov, sigma=sigma, evals=evals, evecs=evecs,
                floored=floored, target_sigma=np.asarray(target_sigma),
                target_mean=np.asarray(target_mean), tol_lo=lo, tol_hi=hi)
    return T, offset, info


def green_desaturate_args(amount, hue_deg=120.0, width_deg=45.0):
    """
    ImageMagick arguments that desaturate hues near `hue_deg` by `amount`
    percent, to be appended after the image on the stack has been produced.

    Stack layout when these run:  [stretched]
        ( +clone -modulate 100,S,100 )         -> [stretched, desaturated]
        ( -clone 0 ... hue mask ... )          -> [stretched, desaturated, mask]
        -compose Over -composite               -> mask blends desaturated over stretched

    The mask is a triangular window of half-width `width_deg` centred on
    `hue_deg`.  It is built without Subtract/Abs so that it behaves the same
    on HDRI and non-HDRI builds (non-HDRI clamps negatives to 0):
        hue  -> AddModulus so the centre lands on 50% (handles wrap-around)
             -> -solarize 50%   folds the ramp: value = 0.5 - |hue - centre|
             -> -level lo%,50%  maps [0.5 - width, 0.5] onto [0, 1] and clamps
    """
    saturation = 100.0 - amount
    shift = (0.5 - hue_deg / 360.0) % 1.0
    lo = 50.0 - (width_deg / 360.0) * 100.0
    return ["(", "+clone", "-modulate", "100,%g,100" % saturation, ")",
            "(", "-clone", "0", "-colorspace", "HSL", "-channel", "R",
            "-separate", "+channel",
            "-evaluate", "AddModulus", "%.6f%%" % (shift * 100.0),
            "-solarize", "50%",
            "-level", "%.6f%%,50%%" % lo,
            ")",
            "-compose", "Over", "-composite"]


def color_matrix_string(T, offset, precision=10):
    """Format T/offset as an ImageMagick 6x6 -color-matrix argument."""
    M = np.eye(6)
    M[:3, :3] = T
    M[:3, 5] = offset
    fmt = "%%.%dg" % precision
    rows = ["  ".join(fmt % v for v in row) for row in M]
    return "6x6: " + "   ".join(rows)


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------
def fmt_vec(v, scale=1.0, prec=4):
    return "[" + ", ".join(("%%.%df" % prec) % (x * scale) for x in v) + "]"


def fmt_mat(M, prec=6, indent="    "):
    return "\n".join(indent + "  ".join(("%%+.%df" % prec) % v for v in row)
                     for row in M)


def corrcoef(pixels):
    sd = pixels.std(axis=0)
    if np.any(sd == 0):
        return np.full((3, 3), np.nan)
    return np.corrcoef(pixels, rowvar=False)


def report(info, T, offset, npix, size, linear):
    e = sys.stderr
    print("Image: %dx%d, %d pixels analysed, colourspace %s"
          % (size[0], size[1], npix, colorspace_of(linear)), file=e)
    print("Band means   (0..255): %s" % fmt_vec(info["mean"], 255, 2), file=e)
    print("Band std dev (0..255): %s" % fmt_vec(info["sigma"], 255, 2), file=e)
    print("Band correlation matrix (input):", file=e)
    sd = info["sigma"]
    print(fmt_mat(info["cov"] / np.outer(sd, sd), 4), file=e)
    print("KL eigenvalues (variance, 0..255^2 units): %s"
          % fmt_vec(info["evals"], 255.0 ** 2, 2), file=e)
    print("KL eigenvectors (columns = principal axes):", file=e)
    print(fmt_mat(info["evecs"], 4), file=e)
    if info["floored"].any():
        print("warning: %d degenerate principal axis/axes floored to avoid "
              "amplifying noise" % info["floored"].sum(), file=e)
    print("Target std dev (0..255): %s" % fmt_vec(info["target_sigma"], 255, 2),
          file=e)
    print("Target mean    (0..255): %s" % fmt_vec(info["target_mean"], 255, 2),
          file=e)
    if info["tol_lo"] is not None:
        print("Tol stretch: per-band quantiles %s -> %s mapped to [0, 1]"
              % (fmt_vec(info["tol_lo"], 255, 1), fmt_vec(info["tol_hi"], 255, 1)),
              file=e)
    print("Transform  y = T (x) + offset   (0..1 units):", file=e)
    print(fmt_mat(T, 6), file=e)
    print("    offset = %s" % fmt_vec(offset, 1.0, 6), file=e)


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Decorrelation stretch using the exact Karhunen-Loeve "
                    "(PCA) transform of the input image, applied through "
                    "ImageMagick -color-matrix.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Examples:")[1])
    ap.add_argument("input", help="input image (any format ImageMagick reads)")
    ap.add_argument("output", nargs="?",
                    help="output image (omit with --matrix-only)")
    ap.add_argument("--tol", type=float, default=0.0, metavar="FRAC",
                    help="after decorrelation, linearly stretch each band so "
                         "that its FRAC and 1-FRAC quantiles map to black and "
                         "white (e.g. 0.01). Default: no extra stretch")
    ap.add_argument("--sigma", default="auto", metavar="S",
                    help="target std dev per band in 0..1 units: 'auto' "
                         "(keep each band's own std dev, default), one "
                         "number, or r,g,b")
    ap.add_argument("--mean", default="auto", metavar="M",
                    help="target mean per band in 0..1 units: 'auto' (keep "
                         "input means, default), one number, or r,g,b")
    ap.add_argument("--linear", action="store_true",
                    help="compute and apply the transform in linear-light "
                         "RGB instead of gamma-encoded sRGB")
    ap.add_argument("--sample", type=int, default=0, metavar="N",
                    help="estimate statistics from at most N evenly spaced "
                         "pixels instead of every pixel (0 = all, exact)")
    ap.add_argument("--desaturate-greens", type=float, default=0.0,
                    metavar="PCT",
                    help="after the stretch, remove PCT percent (0-100) of "
                         "the saturation of green hues. Applied by "
                         "ImageMagick as a hue-masked post-stage; not part "
                         "of the colour matrix. Default: 0 (off)")
    ap.add_argument("--green-hue", type=float, default=120.0, metavar="DEG",
                    help="centre of the hue window used by "
                         "--desaturate-greens, in degrees (default 120 = "
                         "pure green; 90 = yellow-green, 150 = blue-green)")
    ap.add_argument("--green-width", type=float, default=45.0, metavar="DEG",
                    help="half-width of the hue window in degrees; the "
                         "effect fades linearly to zero at +/- DEG from the "
                         "centre (default 45)")
    ap.add_argument("--matrix-only", action="store_true",
                    help="print the -color-matrix argument to stdout and exit "
                         "without writing an output image")
    ap.add_argument("--verify", action="store_true",
                    help="re-read the output and print its band correlation "
                         "matrix (should be ~identity) and std devs")
    ap.add_argument("--magick", metavar="PATH",
                    help="ImageMagick executable (default: magick, then convert)")
    ap.add_argument("-q", "--quiet", action="store_true",
                    help="suppress the statistics report on stderr")
    args = ap.parse_args(argv)

    if not args.matrix_only and not args.output:
        ap.error("output is required unless --matrix-only is given")
    if not (0.0 <= args.tol < 0.5):
        ap.error("--tol must be in [0, 0.5)")
    if not (0.0 <= args.desaturate_greens <= 100.0):
        ap.error("--desaturate-greens must be in [0, 100]")
    if not (0.0 < args.green_width <= 180.0):
        ap.error("--green-width must be in (0, 180]")
    if args.matrix_only and args.desaturate_greens > 0:
        print("warning: --desaturate-greens is a post-stage and is not "
              "included in the --matrix-only output", file=sys.stderr)

    magick = find_magick(args.magick)

    # 1. Pull the pixel data of this specific image out of ImageMagick.
    pixels, size = read_pixels(magick, args.input, args.linear)
    if args.sample and args.sample < len(pixels):
        step = int(np.ceil(len(pixels) / args.sample))
        pixels = pixels[::step]

    # 2. Exact KL transform + decorrelation stretch.
    T, offset, info = decorrelation_matrix(
        pixels,
        target_sigma=parse_triplet(args.sigma, "sigma"),
        target_mean=parse_triplet(args.mean, "mean"),
        tol=args.tol)
    matrix = color_matrix_string(T, offset)

    if not args.quiet:
        report(info, T, offset, len(pixels), size, args.linear)
        print("ImageMagick -color-matrix argument:\n    \"%s\"" % matrix,
              file=sys.stderr)

    if args.matrix_only:
        print(matrix)
        return 0

    # 3. Hand the matrix to ImageMagick.  -color-matrix clamps results to the
    #    quantum range, which is exactly the saturation behaviour a
    #    decorrelation stretch is expected to have.
    cmd = magick + [args.input, "-alpha", "off"]
    if args.linear:
        cmd += ["-colorspace", "RGB"]
    cmd += ["-color-matrix", matrix]
    if args.linear:
        cmd += ["-colorspace", "sRGB"]
    if args.desaturate_greens > 0:
        # Hue-selective, so it cannot be folded into the matrix; it runs on
        # the stretched image where the greens actually show up.
        cmd += green_desaturate_args(args.desaturate_greens,
                                     args.green_hue, args.green_width)
        if not args.quiet:
            print("Green desaturation: -%g%% saturation for hues %g +/- %g deg"
                  % (args.desaturate_greens, args.green_hue, args.green_width),
                  file=sys.stderr)
    cmd += [args.output]
    if not args.quiet:
        print("Running: " + " ".join(
            ('"%s"' % c) if " " in c else c for c in cmd), file=sys.stderr)
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit("error: ImageMagick failed:\n" + proc.stderr)
    if proc.stderr.strip():
        print(proc.stderr.strip(), file=sys.stderr)

    if args.verify:
        out_pix, _ = read_pixels(magick, args.output, args.linear)
        print("Verification of %s:" % args.output, file=sys.stderr)
        print("Band std dev (0..255): %s" % fmt_vec(out_pix.std(axis=0), 255, 2),
              file=sys.stderr)
        print("Band correlation matrix (output; identity = fully decorrelated, "
              "clipping adds small residuals):", file=sys.stderr)
        print(fmt_mat(corrcoef(out_pix), 4), file=sys.stderr)
        if args.desaturate_greens > 0:
            print("note: --desaturate-greens re-introduces some correlation "
                  "in green areas by design", file=sys.stderr)

    print("wrote %s" % args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
