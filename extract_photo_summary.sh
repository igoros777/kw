#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                              igor@igoros.com
#                                 2026-02-04
# ----------------------------------------------------------------------------
# Extract photo EXIF metadata, rewrite it consicely, and save as a comment
# ----------------------------------------------------------------------------
# Change Log:
# ****************************************************************************
# 2026-02-04	igor@igoros.com	Wrote this script
# ****************************************************************************
input_file="${1}"
if [ -z "${input_file}" ] || [ ! -f "${input_file}" ]
then
  echo "Usage: ${0} <image-file>"
  exit 1
fi

# ----------------------------------------------------------------------------
# FUNCTIONS
# ----------------------------------------------------------------------------
configure() {
  # Geocod.io API key
  v='v1.7'
  apibase="https://api.geocod.io/${v}"
  api_key="Get your API key from https://www.geocod.io"
}

convert_function() {
  coordinates="$(exiftool -q -m -n -p '$GPSLatitude,$GPSLongitude' "${input_file}")"
  location="$(curl -s0 -q -k "${apibase}/reverse?q=${coordinates}&api_key=${api_key}&limit=1" | \
    jq -r '.results[]|"\(.formatted_address)"' 2>/dev/null)"
  if [ -z "${location}" ]
  then
    lat="$(echo "${coordinates}" | awk -F, '{print $1}' | sed 's/[0-9]$//')"
    lon="$(echo "${coordinates}" | awk -F, '{print $2}' | sed 's/[0-9]$//')"
    coordinates="${lat},${lon}"
    location="$(curl -s0 -q -k "${apibase}/reverse?q=${coordinates}&api_key=${api_key}&limit=1" | \
    jq -r '.results[]|"\(.formatted_address)"' 2>/dev/null)"
  fi
  if [ -z "${location}" ]
  then
    location="Mystery Town, USA"
  fi
}
export -f convert_function

extract_metadata() {
  local file="${input_file}"
  local make model lens iso aperture shutter focal wb meter flash exp_comp
  local width height resolution file_size color_space orientation dt offset
  local gps_lat gps_lon gps_alt gps location_out
  local dt_human

  human_time() {
    local raw="${1}"
    local normalized date_str dow hour phrase time_of_day timing

    if [ -z "${raw}" ] || [ "${raw}" = "N/A" ]; then
      echo "N/A"
      return
    fi

    normalized="${raw}"
    if echo "${normalized}" | grep -qE '^[0-9]{4}:[0-9]{2}:[0-9]{2}'; then
      normalized="$(echo "${normalized}" | sed 's/^\([0-9]\{4\}\):\([0-9]\{2\}\):\([0-9]\{2\}\)/\1-\2-\3/')"
    fi

    date_str="$(date -d "${normalized}" '+%b %e, %Y' 2>/dev/null | sed 's/  / /g')"
    dow="$(date -d "${normalized}" '+%a' 2>/dev/null)"
    hour="$(date -d "${normalized}" '+%H' 2>/dev/null)"

    if [ -z "${date_str}" ] || [ -z "${dow}" ] || [ -z "${hour}" ]; then
      echo "${raw}"
      return
    fi

    case "${hour}" in
      00|01|02|03|04) timing="late"; time_of_day="night" ;;
      05|06|07)       timing="early"; time_of_day="morning" ;;
      08|09|10)       timing=""; time_of_day="morning" ;;
      11|12)          timing="late"; time_of_day="morning" ;;
      13|14|15)       timing="early"; time_of_day="afternoon" ;;
      16|17)          timing="late"; time_of_day="afternoon" ;;
      18|19)          timing="early"; time_of_day="evening" ;;
      20|21)          timing="late"; time_of_day="evening" ;;
      22|23)          timing=""; time_of_day="night" ;;
      *)              timing=""; time_of_day="day" ;;
    esac

    if [ -n "${timing}" ]; then
      phrase="${timing} ${dow} ${time_of_day}"
    else
      phrase="${dow} ${time_of_day}"
    fi

    echo "${date_str}, ${phrase}"
  }

  make="$(exiftool -s -s -s -Make "${file}" 2>/dev/null)"
  [ -z "${make}" ] && make="N/A"

  model="$(exiftool -s -s -s -Model "${file}" 2>/dev/null)"
  [ -z "${model}" ] && model="N/A"

  lens="$(exiftool -s -s -s -LensModel "${file}" 2>/dev/null)"
  [ -z "${lens}" ] && lens="$(exiftool -s -s -s -Lens "${file}" 2>/dev/null)"
  [ -z "${lens}" ] && lens="$(exiftool -s -s -s -LensID "${file}" 2>/dev/null)"
  [ -z "${lens}" ] && lens="N/A"

  iso="$(exiftool -s -s -s -ISO "${file}" 2>/dev/null)"
  [ -z "${iso}" ] && iso="N/A"

  aperture="$(exiftool -s -s -s -FNumber "${file}" 2>/dev/null)"
  [ -z "${aperture}" ] && aperture="$(exiftool -s -s -s -ApertureValue "${file}" 2>/dev/null)"
  if [ -n "${aperture}" ]; then
    case "${aperture}" in
      f/*) : ;;
      *) aperture="f/${aperture}" ;;
    esac
  else
    aperture="N/A"
  fi

  shutter="$(exiftool -s -s -s -ExposureTime "${file}" 2>/dev/null)"
  [ -z "${shutter}" ] && shutter="$(exiftool -s -s -s -ShutterSpeed "${file}" 2>/dev/null)"
  [ -z "${shutter}" ] && shutter="N/A"

  focal="$(exiftool -s -s -s -FocalLength "${file}" 2>/dev/null)"
  [ -z "${focal}" ] && focal="$(exiftool -s -s -s -FocalLengthIn35mmFormat "${file}" 2>/dev/null)"
  [ -z "${focal}" ] && focal="N/A"

  wb="$(exiftool -s -s -s -WhiteBalance "${file}" 2>/dev/null)"
  [ -z "${wb}" ] && wb="$(exiftool -s -s -s -WhiteBalanceMode "${file}" 2>/dev/null)"
  [ -z "${wb}" ] && wb="N/A"

  meter="$(exiftool -s -s -s -MeteringMode "${file}" 2>/dev/null)"
  [ -z "${meter}" ] && meter="N/A"

  flash="$(exiftool -s -s -s -Flash "${file}" 2>/dev/null)"
  [ -z "${flash}" ] && flash="N/A"

  exp_comp="$(exiftool -s -s -s -ExposureCompensation "${file}" 2>/dev/null)"
  if [ -n "${exp_comp}" ]; then
    case "${exp_comp}" in
      *EV*) : ;;
      *) exp_comp="${exp_comp} EV" ;;
    esac
  else
    exp_comp="N/A"
  fi

  width="$(exiftool -s -s -s -ImageWidth "${file}" 2>/dev/null)"
  height="$(exiftool -s -s -s -ImageHeight "${file}" 2>/dev/null)"
  if [ -n "${width}" ] && [ -n "${height}" ]; then
    resolution="${width}x${height}"
  else
    resolution="$(exiftool -s -s -s -ImageSize "${file}" 2>/dev/null)"
  fi
  [ -z "${resolution}" ] && resolution="N/A"

  file_size="$(exiftool -s -s -s -FileSize "${file}" 2>/dev/null)"
  [ -z "${file_size}" ] && file_size="N/A"

  color_space="$(exiftool -s -s -s -ColorSpace "${file}" 2>/dev/null)"
  [ -z "${color_space}" ] && color_space="$(exiftool -s -s -s -ProfileDescription "${file}" 2>/dev/null)"
  [ -z "${color_space}" ] && color_space="$(exiftool -s -s -s -ICCProfileName "${file}" 2>/dev/null)"
  [ -z "${color_space}" ] && color_space="N/A"

  orientation="$(exiftool -s -s -s -Orientation "${file}" 2>/dev/null)"
  [ -z "${orientation}" ] && orientation="N/A"

  dt="$(exiftool -s -s -s -DateTimeOriginal "${file}" 2>/dev/null)"
  [ -z "${dt}" ] && dt="$(exiftool -s -s -s -CreateDate "${file}" 2>/dev/null)"
  [ -z "${dt}" ] && dt="$(exiftool -s -s -s -FileModifyDate "${file}" 2>/dev/null)"
  offset="$(exiftool -s -s -s -OffsetTimeOriginal "${file}" 2>/dev/null)"
  if [ -n "${offset}" ] && ! echo "${dt}" | grep -qE "[+-][0-9]{2}:?[0-9]{2}"; then
    dt="${dt} ${offset}"
  fi
  [ -z "${dt}" ] && dt="N/A"
  dt_human="$(human_time "${dt}")"

  gps_lat="$(exiftool -s -s -s -n -GPSLatitude "${file}" 2>/dev/null)"
  gps_lon="$(exiftool -s -s -s -n -GPSLongitude "${file}" 2>/dev/null)"
  gps_alt="$(exiftool -s -s -s -n -GPSAltitude "${file}" 2>/dev/null)"
  if [ -n "${gps_alt}" ]; then
    gps_alt="${gps_alt} m"
  else
    gps_alt="N/A"
  fi
  if [ -n "${gps_lat}" ] && [ -n "${gps_lon}" ]; then
    gps="${gps_lat}, ${gps_lon}, ${gps_alt}"
  else
    gps="N/A"
  fi
  convert_function 
  location_out="${location:-Unknown Location}"

  printf '%s | %s | ISO: %s | %s | %s | %s | WB: %s | Metering: %s | Flash: %s | ExpComp: %s | %s | %s | %s | %s\n' \
    "${model}" "${lens}" "${iso}" "${aperture}" "${shutter}" "${focal}" "${wb}" "${meter}" "${flash}" "${exp_comp}" "${resolution}" "${color_space}" "${dt_human}" "${location_out}"
}
export -f extract_metadata

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
configure
extract_metadata 
