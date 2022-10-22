#!/bin/bash
# Rename GoPro videos in the current folder to include:
# Date the video was taken
# Full address
# Duration in seconds
# Original filename
#
# Example:
# 20220706-1128-000-190_s_park_st_lake_city_co_81235-31s-GH010135.MP4.mp4

v='v1.7'
apibase="https://api.geocod.io/${v}"
api_key="Get your API key from https://www.geocod.io"

convert_function() {
  echo "Renaming ${1}"
  orig_name="$(basename "${1}")"

  coordinates="$(exiftool -q -m -n -p '$GPSLatitude,$GPSLongitude' "${1}")"

  location="$(curl -s0 -q -k "${apibase}/reverse?q=${coordinates}&api_key=${api_key}&limit=1" | \
    jq -r '.results[]|"\(.formatted_address)"' 2>/dev/null | \
    sed -e 's/\(.*\)/\L\1/' -e 's/[^A-Za-z0-9._-]/_/g' -e 's/__/_/g')"

  if [ -z "${location}" ]
  then
    lat="$(echo "${coordinates}" | awk -F, '{print $1}' | sed 's/[0-9]$//')"
    lon="$(echo "${coordinates}" | awk -F, '{print $2}' | sed 's/[0-9]$//')"
    coordinates="${lat},${lon}"
    location="$(curl -s0 -q -k "${apibase}/reverse?q=${coordinates}&api_key=${api_key}&limit=1" | \
    jq -r '.results[]|"\(.formatted_address)"' 2>/dev/null | \
    sed -e 's/\(.*\)/\L\1/' -e 's/[^A-Za-z0-9._-]/_/g' -e 's/__/_/g')"
  fi

  if [ -z "${location}" ]
  then
    location="mystery_town"
  fi

  dt="$(exiftool -duration "${1}" | grep -oE "([0-9]{1,}:){1,}?([0-9]{1,}){1,}([0-9]{1,}\.[0-9]{1,})?")"
  if [ $(echo ${dt} | grep -c :) -eq 0 ]; then dt="00:00:${dt}"; fi

  duration="$(date -d "1970-01-01 ${dt}Z" +%s)s"
  if [ -z "${duration}" ]; then duration=0s; fi

  exiftool '-filename<${CreateDate}.%le' -d "%Y%m%d-%H%M%%-03.c-${location}-${duration}-${orig_name}" "${1}" 2>/dev/null
}
export -f convert_function

find . -mindepth 1 -maxdepth 1 -type f -name "*\.MP4" | while read i; do convert_function "${i}"; done
