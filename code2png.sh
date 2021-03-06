#!/bin/bash
fmt=svg
out=png
lang="${3}"
ext="${4}"
dpi=300
wsize=1920
source_path="${1}"
target_path="${2}"
if [ -z "${source_path}" ] || [ -z "${target_path}" ] || [ -z "${lang}" ]; then exit 1; fi
if [ ! -f "${source_path}" ] && [ -z "${ext}" ]; then exit 3; fi
if [ -f "${source_path}" ] && [ -z "${ext}" ]; then ext="*"; fi
if [ ! -d "${target_path}" ]; then mkdir -p "${target_path}" || exit 2; fi
find "${source_path}" -maxdepth 1 -mindepth 0 -type f -name "*\.${ext}" | while read f
do
  pygmentize -O "style=monokai,fontface=DejaVu Sans Mono,fontsize=24" -f "${fmt}" \
  -l ${lang} -o "${target_path}/$(basename -- "${f%.*}").${fmt}" "${f}" 2>/dev/null
  inkscape -z -D --export-area-snap -b '#272822' -w ${wsize} -d ${dpi} \
  "${target_path}/$(basename -- "${f%.*}").${fmt}" \
  -e "${target_path}/$(basename -- "${f%.*}").${out}" 2>/dev/null
  mogrify -path "${target_path}" -bordercolor '#272822' -border 20 \
  -format png "${target_path}/$(basename -- "${f%.*}").${out}"
  /bin/rm "${target_path}/$(basename -- "${f%.*}").${fmt}" 2>/dev/null
done
