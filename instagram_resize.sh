#!/bin/bash
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                  2021-12-11
#
# ----------------------------------------------------------
# Add borders to photos to meet allowable Instagram
# aspect ratios for posts.
# ----------------------------------------------------------

configure() {
  # Maximum allowable image ratios
  msize=2048   # Maximum longest side
  l="1.91/1"   # Maximum landscape ratio
  p="4/5"      # Maximum portrait ratio
  border="5x5" # Image border

  # Input and output folders
  d="/mnt/c/zip/ig_test"
  q="${d}/in"   # Put original files here
  t="${d}/out"  # Processed files will be saved here

  # Check for folders and files
  if [ ! -d "${d}" ]; then
    echo "Source folder ${d} not found. Exiting..."
    exit 1
  elif [ ! -d "${q}" ]; then
    echo "Source folder ${q} not found. Exiting..."
    exit 1
  elif [ $(ls "${q}" | grep -iPc "\.(jpg|jpeg|gif|png|tif|tiff)$") -eq 0 ]; then
    echo "Could not find any images in the source folder ${q}. Exiting..."
    exit 1
  elif [ ! -d "${t}" ]; then
    mkdir -p "${t}"
  fi
}

avg_color() {
  # Determine complimentary background and border colors
  c="$(convert "${q}/${i}" -resize 1x1\! -format "%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]" info:-)"
  ic="$(convert "${q}/${i}" -resize 1x1\! -format "%[fx:int(255*r+.5)],%[fx:int(255*g+.5)],%[fx:int(255*b+.5)]" -negate info:-)"
}

image_convert() {
  rpp="$(identify -format "%[fx:abs(h/w)]" "${q}/${i}" 2>/dev/null)"
  rll="$(identify -format "%[fx:abs(w/h)]" "${q}/${i}" 2>/dev/null)"
  if [ ! -z "${rpp}" ] && [ ! -z "${rll}" ]; then
    if (( $(echo "${rpp} > ${rll}" | bc -l) )); then
      # Portrait
      avg_color
      if [ $(convert "${q}/${i}" -ping -format "%[fx:(1*h)]" info:) -gt "${msize}" ]; then
        sizey=${msize}
      else
        sizey="$(convert "${q}/${i}" -ping -format "%[fx:(1*h)]" info:)"
      fi
      sizex="$(echo "scale=0;${sizey}/${rpp}" | bc -l)"
      o="$(echo "${i%.*}_${sizex}x${sizey}.jpg")"
      echo "Converting ${q}/${i} to ${t}/${o}"
      convert "${q}/${i}" \
      -trim +repage \
      -resize "${sizex}x${sizey}>" \
      -gravity center \
      -bordercolor "rgb(${ic})" -border ${border} \
      -background "rgb(${c})" \
      -extent "$(convert "${q}/${i}" -ping -format "%[fx:((${sizey}*${p})+1)]" info:)x${sizey}" \
      "${t}/${o}"
    else
      # Landscape
      avg_color
      if [ $(convert "${q}/${i}" -ping -format "%[fx:(1*w)]" info:) -gt "${msize}" ]; then
        sizex=${msize}
      else
        sizex="$(convert "${q}/${i}" -ping -format "%[fx:(1*w)]" info:)"
      fi
      sizey="$(echo "scale=0;${sizex}/${rll}" | bc -l)"
      o="$(echo "${i%.*}_${sizex}x${sizey}.jpg")"
      echo "Converting ${q}/${i} to ${t}/${o}"
      convert "${q}/${i}"\
      -trim +repage \
      -resize "${sizex}x${sizey}>" \
      -gravity center \
      -bordercolor "rgb(${ic})" -border ${border} \
      -background "rgb(${c})" \
      -extent "${sizex}x$(convert "${q}/${i}" -ping -format "%[fx:((${sizex}/${l})+1)]" info:)" \
      "${t}/${o}"
    fi
  fi
}

image_process() {
  find "${q}" -mindepth 1 -maxdepth 1 -type f -printf "%f\n" | grep -iP "\.(jpg|jpeg|gif|png|tif|tiff)$" | while read i; do
    rp="$(identify -format "%[fx:abs((${p})-(h/w))]" "${q}/${i}" 2>/dev/null)"
    rl="$(identify -format "%[fx:abs((${l})-(w/h))]" "${q}/${i}" 2>/dev/null)"
    if [ ! -z "${rp}" ] && [ ! -z "${rl}" ]; then
      if (( $(echo "${rp} > 1" | bc -l) )) || (( $(echo "${rl} > 1" | bc -l) )); then
        image_convert "${i}"
      else
        /bin/cp -p "${q}/${i}" "${t}/${i}"
      fi
    else
      echo "Image ${i} may exceed your ImageMagick limits set in policy.xml"
    fi
  done
}

# RUNTIME

configure
image_process
