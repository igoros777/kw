#!/bin/bash

usage() {
  cat << EOF
  video-processor -a [makeframes|reassemble|copysound|sidebyside] [-f "/fullpath/original video.mp4"]
EOF
  exit 110
}

while getopts ":a:f:h:" OPTION; do
	case "${OPTION}" in
		a)
			a="${OPTARG}"
			;;
    f)
      original="${OPTARG}"
      ;;
		h)
      usage
      ;;
		\? ) echo "Unknown option: -$OPTARG" >&2; usage;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; usage;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; usage;;
	esac
done

case "${a}" in
  makeframes) : ;;
  reassemble) : ;;
  copysound) : ;;
  sidebyside) : ;;
  *) echo "Unknown action ${a}"; usage;;
esac

if [ -z "${original}" ]
then
  IFS= read -r -p "Full path to video: " original
  original="$(echo "${original}" | sed -r 's/(^\"|\"$)//g')"
fi

configure() {
  if ! command -v ffmpeg >/dev/null 2>&1
  then
    echo "You need to install 'ffmpeg'. Exiting..."
    exit 124
  fi
  if [ ! -f "${original}" ]
  then
    echo "File ${original} not found. Exiting..."
    exit 125
  fi
  original_filename="$(filename "${original}")"
  original_pathname="$(dirname "${original}")"
  if [ ! -f "${original_pathname}/${original_filename}" ]
  then
    echo "Unable to parse {original}. Exiting..."
    exit 126
  fi
  original_framerate="$(ffmpeg -i "${original}" 2>&1 | sed -n "s/.*, \(.*\) fp.*/\1/p")"
  read -r original_w original_h <<< "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of default=nw=1:nk=1 "${original}" | xargs)"
  if [ -z "${original_framerate}" ] || [ -z "${original_w}" ] || [ -z "${original_h}" ]
  then
    echo "Unable to determine original video framerate or resolution. Exiting..."
    exit 127
  fi
}

makeframes() {
  if [  -d "${original_pathname}/${original_filename}_tmp/lightroom_in" ]
  then
    echo "Looks like ${original_pathname}/${original_filename}_tmp already exists. Remove it first. Exiting..."
    exit 128
  fi
  cd "${original_pathname}" || exit 130
  echo "Processing ${original}"
  mkdir -p "${original_pathname}/${original_filename}_tmp/lightroom_in"
  mkdir -p "${original_pathname}/${original_filename}_tmp/lightroom_out"
  /bin/cp -p "${original}" "${original_pathname}/${original_filename}_tmp/"
  cd "${original_pathname}/${original_filename}_tmp/" || exit
  ffmpeg -r 1 -i "${original_filename}" -r 1 "frame_%09d.png" 2>/dev/null 1>&2
  /bin/mv ./*png ./lightroom_in/
  echo -e "\tCreated $(/bin/ls ./lightroom_in | wc -l) frames in ${original}" "${original_pathname}/${original_filename}_tmp/lightroom_out/"
}

re_assemble() {
  if [ ! -d "${original_pathname}/${original_filename}_tmp/lightroom_out" ]
  then
    echo "Missing ${original_pathname}/${original_filename}_tmp/lightroom_out. Exiting..."
    exit 129
  fi

  if [ "$(find "${original_pathname}/${original_filename}_tmp/lightroom_out/" -mindepth 1 -maxdepth 1 -type f -name "*.png" | wc -l)" -lt 2 ]
  then
    echo "Don't see any PNG files in ${original_pathname}/${original_filename}_tmp/lightroom_out. Exiting..."
    exit 137
  fi

  echo "Re-assembling PNG files in ${original_pathname}/${original_filename}_tmp/lightroom_out"

  ffmpeg -r "${original_framerate}" -f image2 -s "${original_w}"x"${original_h}" \
  -i "${original_pathname}/${original_filename}_tmp/lightroom_out/"frame_%09d.png \
  -vcodec libx264 -crf 25  -pix_fmt yuv420p \
  "${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled.mp4" 2>/dev/null 1>&2

  echo "Reassembled video without sound in ${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled.mp4"
}

copy_sound() {
  if [ ! -f "${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled.mp4" ]
  then
    echo "Missing ${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled.mp4. Exiting..."
    exit 139
  fi

  ffmpeg -i "${original}" \
  -i "${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled.mp4" \
  -c copy -map 0:a -map 1:v -shortest \
  "${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled_with_sound.mp4" 2>/dev/null 1>&2

  echo "Reassembled video with sound in ${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled_with_sound.mp4"
}

side_by_side() {
  if [ ! -f "${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled_with_sound.mp4" ]
  then
    echo "Missing ${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled_with_sound.mp4. Exiting..."
    exit 145
  fi

  echo "Generating a side-by-side video from original and re-assembled versions."

  ffmpeg -i "${original}" \
  -i "${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled_with_sound.mp4" \
  -vcodec libx264 \
  -filter_complex "[0:v]setpts=PTS-STARTPTS, pad=iw*2:ih[bg]; [1:v]setpts=PTS-STARTPTS[fg]; [bg][fg]overlay=w" \
  "${original_pathname}/${original_filename}_tmp/${original_filename%.*}_reassembled_with_sound_sbs.mp4" 2>/dev/null 1>&2

  echo "Side-by-side video in ${original_pathname}/${original_filename}_tmp/${original_filename}_tmp/${original_filename%.*}_reassembled_with_sound_sbs.mp4"
}

# RUNTIME
case "${a}" in
  makeframes) configure; makeframes ;;
  reassemble) configure; re_assemble ;;
  copysound) configure; copy_sound ;;
  sidebyside) configure; side_by_side ;;
  *) echo "Unknown action ${a}"; usage;;
esac
