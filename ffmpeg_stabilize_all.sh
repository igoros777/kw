#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                          igor.oseledko@cscglobal.com
#                                 2024-06-08
# ----------------------------------------------------------------------------
# Stabilize all videos in a directory using ffmpeg
# Documentation URL: https://www.igoroseledko.com/compile-ffmpeg-from-source/
# Usage: ./ffmpeg_stabilize_all.sh [input_dir] [output_dir]
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2024-06-08  igor  wrote this script
# ----------------------------------------------------------------------------


input_dir="$1"
output_dir="$2"

if [ -z "$input_dir" ] || [ -z "$output_dir" ]; then
    echo "Both input and output directories must be provided."
    exit 1
fi

if [ ! -d "$input_dir" ]; then
    echo "The input directory $input_dir does not exist."
    exit 1
fi

mkdir -p "${output_dir}"

FFMPEG=/usr/local/bin/ffmpeg

if [ ! -e "${FFMPEG}" ]; then
    FFMPEG=$(command -v ffmpeg)
    if [ -z "${FFMPEG}" ]; then
        echo "ffmpeg could not be found. Please install it first."
        exit 1
    fi
fi

if ! $FFMPEG -filters 2>/dev/null | grep -q vidstab; then
    echo "Your version of ffmpeg does not support VidStab"
    echo "Please check ${url} for more information."
    exit 1
fi

url="https://www.igoroseledko.com/compile-ffmpeg-from-source/"
# ffmpeg parameters
level=30
shakiness=10
accuracy=15


cd "${input_dir}" || exit
for file in "${input_dir}"/*; do
  if [[ "${file}" != *.trf ]]; then
    echo "Processing ${file}"
    filename=$(basename "${file}")
    output_file="${output_dir}/${filename}"
    ${FFMPEG} -v 3 -i "${file}" -vf vidstabdetect=shakiness=${shakiness}:accuracy=${accuracy} -f null -
    ${FFMPEG} -v 3 -i "${file}" -vf vidstabtransform=smoothing=${level}:input="transforms.trf" \
    -c:v libx264 -preset veryfast -crf 12 -tune film \
    "${output_file}"
    /bin/rm transforms.trf
  fi
done