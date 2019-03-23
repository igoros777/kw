#!/bin/bash
f="${1}"; if [ -z "${f}" ]; then f="$(awk '{print $2}' <(grep "^/dev" /etc/mtab))"; fi
l="${2}"; if [ -z "${l}" ]; then l=4; fi
h=$(echo ${HOSTNAME} | awk -F. '{print $1}')
d=$(date +'%Y-%m-%d %H:%M:%S')
for i in ${f}; do
  find ${i} -maxdepth ${l} -xdev -type d -name log -o -name logs -o -name tmp -o -name temp -exec du -skx {} \; | awk '$1>204800{system("du -shx "$2)}'
done
