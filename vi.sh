#!/bin/bash
for f in "${@}"
do
  if [ -f "${f}" ]
  then
    /bin/cp -p "${f}" "$(dirname "${f}")/$(basename -- "${f%.*}")_$(date -d @$(stat -c %Y "${f}") +'%Y-%m-%d_%H%M%S')@$(date +'%Y-%m-%d_%H%M%S')$([[ "${f}" = *.* ]] && echo ".${f##*.}" || echo '')"
  fi
done
exec vim "${@}"
