#!/bin/bash
f="${1}"; if [ -z "${f}" ]; then f="$(awk '{print $2}' <(grep "^/dev" /etc/mtab))"; fi
l="${2}"; if [ -z "${l}" ]; then l=10; fi
h=$(echo ${HOSTNAME} | awk -F. '{print $1}')
d=$(date +'%Y-%m-%d %H:%M:%S')
for i in ${f}; do
  find "${i}" -xdev -printf "${d},${h},%s,%TY-%Tm-%Td_%TH:%TM,%u:%g,%m,%n,%p\n" | sort -t, -k3rn | head -${l}
done | (echo "DATE,HOST,KB,MTIME,UID:GID,RWX,HL,PATH" && cat) | column -s',' -t
