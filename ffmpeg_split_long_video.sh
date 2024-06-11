#!/bin/bash

random="${RANDOM}"
font="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

if [ ! -f "${font}" ]; then
    echo "Font file not found. Please update the font path in the script." >&2
    exit 1
fi

# Function to convert seconds to HH:MM:SS format
convert_to_hms() {
    local total_seconds=$1
    printf "%02d:%02d:%02d" $(("${total_seconds}"/3600)) $(("${total_seconds}"%3600/60)) $(("${total_seconds}"%60))
}

# Parse command line arguments
while getopts f:d: flag
do
  case "${flag}" in
      f) video_path=${OPTARG};;
      d) segment_length_minutes=${OPTARG};;
      *) echo "Invalid flag: ${flag}" >&2
         exit 1;;
  esac
done

if [[ -z "${video_path}" || -z "${segment_length_minutes}" ]]; then
    echo "Usage: $0 -f [input video file path] -d [max duration of each segment in minutes]"
    exit 1
fi

if [[ "$segment_length_minutes" =~ ^[0-9]+$ ]] ; then
   .
else
   echo "Error: Video duration must be a positive integer."
   exit 1
fi

if [ ! -f "${video_path}" ]; then
    echo "Input video file not found." >&2
    exit 1
fi

# Convert segment length from minutes to seconds 
segment_length=$(("${segment_length_minutes}" * 60))

# Get the duration of the video in seconds
duration=$(ffprobe -i "${video_path}" -show_entries format=duration -v quiet -of csv="p=0")

# Calculate the number of segments needed
num_segments=$(echo "($duration / $segment_length) + 1" | bc)

# Use ffmpeg to split the video and add text
for ((i=0; i<num_segments; i++)); do
    start_time=$(echo "$i * ${segment_length}" | bc)
    start_time_hms=$(convert_to_hms "${start_time}")
    output_file=$(printf "segment_${random}_%03d.mp4" $i)
    part_number=$(printf "Part %d" $((i+1)))

    # The following command will also attach the "Part X" text to the video. If you don't want that, 
    # you can remove the `-vf` option and that entire line from the command below.
    ffmpeg -ss "${start_time_hms}" -i "${video_path}" \
    -vf "drawtext=fontfile=${font}:text='${part_number}':x=10:y=10:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=5" \
    -t "${segment_length}" -c:a copy -y "${output_file}"
done
