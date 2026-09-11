# decorrstretch.py - Decorrelation stretch with an exact per-image PCA matrix

`decorrstretch.py` computes the Karhunen-Loeve (PCA) transform of one specific
image's RGB pixel data and hands the result to ImageMagick's `-color-matrix`
operator as a single 6x6 matrix. The effect is the classic *decorrelation
stretch* used in remote sensing and rock-art enhancement (the same algorithm as
MATLAB's `decorrstretch`): highly correlated colour bands are decorrelated so
that subtle hue differences hidden in a muddy, low-saturation image get spread
across the whole gamut.

Nothing is hard-coded. The mean vector, covariance matrix, eigenvectors and the
final matrix are recomputed for every input image.

## Requirements

- Python 3.8 or newer
- NumPy (`pip install numpy`)
- ImageMagick 6 or 7. The script looks for `magick`, then `convert`, on `PATH`.
  You can also point it at a binary with `--magick` or the `MAGICK` environment
  variable. On Windows `convert.exe` is also a filesystem tool, so the script
  checks the `-version` banner to make sure it really found ImageMagick.

Pixels are pulled out of ImageMagick as a 16-bit PPM stream, so Pillow is not
required.

## Basic usage

```bash
python decorrstretch.py input.jpg output.png
```

The output keeps each band's original mean and standard deviation but the
bands are now uncorrelated. A statistics report is printed on stderr:

```
Image: 320x240, 76800 pixels analysed, colourspace sRGB
Band means   (0..255): [86.81, 86.68, 78.01]
Band std dev (0..255): [48.21, 48.10, 43.32]
Band correlation matrix (input):
    +1.0000  +0.9740  +0.9720
    +0.9740  +1.0000  +0.9999
    +0.9720  +0.9999  +1.0000
KL eigenvalues (variance, 0..255^2 units): [0.08, 80.37, 6433.77]
KL eigenvectors (columns = principal axes):
    +0.0246  -0.8039  -0.5942
    -0.6822  +0.4210  -0.5978
    +0.7308  +0.4201  -0.5380
Transform  y = T (x) + offset   (0..1 units):
    +3.789431  -4.435145  +1.406521
    -4.425503  +79.374684  -82.640042
    +1.264014  -74.428821  +81.842693
    offset = [0.127695, 0.147145, 0.137695]
ImageMagick -color-matrix argument:
    "6x6: 3.789431109  -4.435144591  1.406521425  0  0  0.1276949565   ..."
```

Add `-q` to silence the report.

## Examples

### Check that the result is really decorrelated

```bash
python decorrstretch.py input.jpg output.png --verify
```

`--verify` re-reads the output and prints its band correlation matrix. It
should be close to the identity; small residuals come from clipping at black
and white and from 8-bit quantisation.

```
Verification of output.png:
Band std dev (0..255): [47.25, 47.07, 42.42]
Band correlation matrix (output; identity = fully decorrelated, clipping adds small residuals):
    +1.0000  +0.0038  +0.0043
    +0.0038  +1.0000  +0.0021
    +0.0043  +0.0021  +1.0000
```

### Add a percentile contrast stretch (MATLAB `Tol`)

```bash
python decorrstretch.py input.jpg output.png --tol 0.01
```

After decorrelation, each band is linearly stretched so that its 1st and 99th
percentiles map to black and white. This is folded into the same colour
matrix, so ImageMagick still runs a single operation.

### Force equal contrast in all bands

```bash
python decorrstretch.py input.jpg output.png --sigma 0.2
```

`--sigma` sets the target standard deviation in 0..1 units. Use one number for
all bands or three comma-separated values (`--sigma 0.2,0.15,0.15`). The
default `auto` keeps each band's own standard deviation.

### Shift the output means

```bash
python decorrstretch.py input.jpg output.png --mean 0.5
```

`--mean` works like `--sigma` and sets the target mean per band. The default
`auto` keeps the input means.

### Work in linear light

```bash
python decorrstretch.py input.jpg output.png --linear
```

Statistics are computed on, and the matrix applied to, linear-light RGB
instead of gamma-encoded sRGB. ImageMagick converts to linear before the
matrix and back to sRGB afterwards.

### Desaturate the greens

```bash
python decorrstretch.py input.jpg output.png --tol 0.01 --desaturate-greens 70
```

A decorrelation stretch often turns vegetation, lichen and moss into garish
green blobs that fight with the pigment you are trying to reveal.
`--desaturate-greens PCT` removes `PCT` percent of the saturation from green
hues after the stretch, leaving the other colours untouched. `100` turns green
areas fully grey; `50` halves their saturation.

The hue window can be tuned:

```bash
# treat yellow-greens as "green" too, and use a wider, softer window
python decorrstretch.py input.jpg output.png --desaturate-greens 80 --green-hue 100 --green-width 60
```

- `--green-hue DEG` is the centre of the window in HSL hue degrees
  (default `120`, pure green; `90` leans yellow-green, `150` leans cyan).
- `--green-width DEG` is the half-width. The effect is full strength at the
  centre and fades linearly to nothing at plus or minus `DEG` (default `45`,
  so hues from 75 to 165 degrees are affected).

This step is hue-selective, so it cannot be expressed in the colour matrix.
The script appends an ImageMagick post-stage that builds a soft hue mask from
the stretched image and blends in a desaturated copy through it. It is not
included in `--matrix-only` output, and `--verify` will show a little
correlation returning in green areas, which is expected.

### Speed up huge images

```bash
python decorrstretch.py huge_scan.tif output.png --sample 200000
```

Statistics are estimated from at most 200,000 evenly spaced pixels instead of
every pixel. The transform is still applied to the full image by ImageMagick.
The default (`0`) uses every pixel and is exact.

### Use the matrix in your own ImageMagick pipeline

```bash
python decorrstretch.py input.jpg --matrix-only -q
```

Prints only the `-color-matrix` argument on stdout, for example:

```
6x6: 3.789431109  -4.435144591  1.406521425  0  0  0.1276949565   -4.425503249  79.37468421  -82.64004199  0  0  0.1471447694   1.264013886  -74.42882128  81.84269278  0  0  0.1376949385   0  0  0  1  0  0   0  0  0  0  1  0   0  0  0  0  0  1
```

Feed it straight to ImageMagick, combined with whatever else you want to do:

```bash
magick input.jpg -color-matrix "$(python decorrstretch.py input.jpg --matrix-only -q)" -resize 50% -unsharp 0x1 output.png
```

PowerShell equivalent:

```powershell
$m = python decorrstretch.py input.jpg --matrix-only -q
magick input.jpg -color-matrix "$m" output.png
```

### Point at a specific ImageMagick binary

```bash
python decorrstretch.py input.jpg output.png --magick "C:\Tools\ImageMagick\magick.exe"
```

## Option summary

| Option | Default | Meaning |
|---|---|---|
| `--tol FRAC` | `0` | Per-band percentile stretch after decorrelation, `FRAC` and `1-FRAC` map to black and white. |
| `--sigma S` | `auto` | Target band std dev in 0..1 units. `auto`, one number, or `r,g,b`. |
| `--mean M` | `auto` | Target band mean in 0..1 units. `auto`, one number, or `r,g,b`. |
| `--linear` | off | Compute and apply in linear-light RGB. |
| `--sample N` | `0` (all) | Estimate statistics from at most `N` evenly spaced pixels. |
| `--desaturate-greens PCT` | `0` (off) | Remove `PCT` percent of the saturation from green hues after the stretch. |
| `--green-hue DEG` | `120` | Centre of the green hue window, in degrees. |
| `--green-width DEG` | `45` | Half-width of the green hue window; effect fades to zero at the edges. |
| `--matrix-only` | off | Print the `-color-matrix` argument and exit. No output image is needed. |
| `--verify` | off | Re-read the output and print its band correlation matrix. |
| `--magick PATH` | auto | ImageMagick executable to use. |
| `-q`, `--quiet` | off | Suppress the statistics report on stderr. |

## How the matrix is built

For pixel vectors `x = (R, G, B)` in 0..1 units:

1. Compute the mean `mu` and the 3x3 covariance `C` of all pixels.
2. Eigendecompose `C = V L V^T`. The columns of `V` are the principal axes
   (the Karhunen-Loeve basis) and `L` holds the variance along each axis.
3. Build the stretch:

   ```
   T      = diag(sigma_target) . V . L^(-1/2) . V^T
   offset = mu_target - T . mu
   y      = T . x + offset
   ```

   `V L^(-1/2) V^T` whitens the data (unit variance along every principal
   axis, zero correlation). `diag(sigma_target)` then gives each output band
   the requested contrast. The output covariance is exactly
   `diag(sigma_target^2)`.
4. If `--tol` is given, the per-band percentile stretch is folded into `T` and
   `offset` as an extra gain and shift.
5. The affine transform is written as an ImageMagick 6x6 colour matrix.
   ImageMagick reads rows 1 to 3 as the R, G, B outputs and column 6 as a
   normalised offset (columns 4 and 5 are the black and alpha inputs, which are
   left untouched):

   ```
   R'   | t00 t01 t02  0  0  oR |   R
   G'   | t10 t11 t12  0  0  oG |   G
   B' = | t20 t21 t22  0  0  oB | . B
   K'   |  0   0   0   1  0   0 |   K
   A'   |  0   0   0   0  1   0 |   A
        |  0   0   0   0  0   1 |   1
   ```

   Values that fall outside 0..1 are clamped by ImageMagick, which is the
   expected saturation behaviour of a decorrelation stretch.
6. With `--desaturate-greens`, ImageMagick then runs this post-stage on the
   stretched image (shown for the defaults, hue 120, half-width 45):

   ```
   ( +clone -modulate 100,30,100 )
   ( -clone 0 -colorspace HSL -channel R -separate +channel
     -evaluate AddModulus 16.6667% -solarize 50% -level 37.5%,50% )
   -compose Over -composite
   ```

   The first clone is the image with 70% of its saturation removed. The
   second builds the mask: the HSL hue channel is rotated so green sits at
   50%, `-solarize` folds the ramp so the value measures distance from green,
   and `-level` turns that into a triangle that is 1 at green and 0 beyond
   the window. The mask then blends the desaturated copy over the original.
   This construction avoids `Subtract`/`Abs`, so it behaves identically on
   HDRI and non-HDRI ImageMagick builds.

## Notes and caveats

- A greyscale or near-greyscale image has a rank-deficient covariance. The
  script floors degenerate eigenvalues and prints a warning instead of blowing
  quantisation noise up to full scale. The result will still look noisy, since
  there is no real colour information to reveal.
- Noise in the input is amplified along the low-variance principal axes. That
  is inherent to the technique, not a bug. Denoise first if it matters.
- Only the first frame of a multi-frame input is analysed. Alpha is dropped
  from the output.
- The transform is computed in the same colourspace it is applied in
  (sRGB by default, linear RGB with `--linear`), so the statistics report and
  the applied matrix always agree.
