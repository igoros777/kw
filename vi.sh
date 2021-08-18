#!/bin/bash
declare -a a an
i=0
for f in "${@}"
do
  if [ -f "${f}" ]
  then
    fn="$(dirname "${f}")/$(basename -- "${f%.*}")_$(date -d @$(stat -c %Y "${f}") +'%Y-%m-%d_%H%M%S')@$(date +'%Y-%m-%d_%H%M%S')$([[ "${f}" = *.* ]] && echo ".${f##*.}" || echo '')"
    a+=("${f}")
    an+=("${fn}")
    /bin/cp -p "${a[$i]}" "${an[$i]}"
    (( i = i + 1 ))
  fi
done
vim "${@}"
if [ $? -eq 0 ]; then
  for ((i = 0; i < ${#a[@]}; i++))
  do
    if cmp -s "${a[$i]}" "${an[$i]}"
    then
      /bin/rm -f "${an[$i]}" 2>/dev/null
    fi
  done
fi
