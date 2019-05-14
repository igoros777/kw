#!/bin/bash
in_dir="/var/tmp"; target_encoder="libx265"
find "${in_dir}" -mindepth 1 -maxdepth 1 -type f -exec file -N -i -- {} + | sed -n 's!: video/[^:]*$!!p' | while read i
do
  p="$(dirname "${i}")"
  n="$(basename "${i}" | awk -F. '{$NF=""; print $0}'| sed 's/ $//g')"
  e="$(basename "${i}" | awk -F. '{print $NF}')"
  b=$(echo "scale=0;$(stat --printf="%s" "${p}/${n}.${e}")/1024/1024"|bc)
  codec="$(ffprobe "${p}/${n}.${e}" 2>&1 >/dev/null | grep -oP "(?<=Video: )[a0-z9]{1,}(?= )")"
  encoder="$(ffmpeg -codecs 2>/dev/null| grep "decoders: ${codec}" | grep -oP "(?<=encoders: )[a0-z9]{1,}(?= )")"
  echo "Converting ${p}/${n}.${e} (${b}MB, ${codec}) to ${p}/${n}_${target_encoder}.${e}"
  ffmpeg -i "${p}/${n}.${e}" -vcodec ${target_encoder} -crf 20 \
  -b $(echo "scale=0; 10^9 / $(ffmpeg -i "${p}/${n}.${e}" 2>&1 | grep -oP -m1 "(?<=ion: )([0-9]{2}(:)?){3}(?=\.[0-9]{2},)" | \
  awk '{split($1,A,":"); split(A[3],B,".");print 3600*A[1]+60*A[2]+B[1]}')"|bc) \
  "${p}/${n}_${target_encoder}.${e}" >/dev/null 2>&1
  a=$(echo "scale=0;$(stat --printf="%s" "${p}/${n}_${target_encoder}.${e}")/1024/1024"|bc)
  (( x = 100 - ( a * 100 / b ) ))
  echo "${p}/${n}_${target_encoder}.${e} is ${x}% smaller than the original"
  printf '%40s\n' | tr ' ' -
done
