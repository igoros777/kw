#!/bin/bash
help() {
  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")" | awk -F. '{print $1}')
  cat << EOF
  SYNTAX:
  ${this_script} <path> [<filename filter>] [<maxdepth>] [<maxcount>]

  EXAMPLES:
  ${this_script} /var/log
  ${this_script} /var/log 192.168.122.13 3 10
  ${this_script} /var/log \* 3 10
EOF
}

if [ -z "${1}" ]; then help; exit 1; fi
d="${1}"
s="${2}"
m="${3}"
if [ -z "${m}" ]; then m=2; fi
c="${4}"
if [ -z "${c}" ]; then c=50; fi
watch -d -n 5 "df -kPl; echo; find \"${d}\" -maxdepth ${m} -mindepth 1 -type f -name \"${s}*\" \
-mtime -1 -exec ls -FlAt {} \; | sort -k9V | column -t | head -${c}"
