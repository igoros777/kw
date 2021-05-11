#!/bin/bash

d="/usr/share/dict/american-english"
if [ ! -f "${d}" ]
then
  echo "Dictionary not found: ${d}. Exiting..."
  exit 1
fi

read -p "Enter the clue: " clues
read -p "Enter the pattern: " pattern

pattern="$(echo "${pattern}" | sed 's/\?/\./g' | sed 's/[A-Z]/\L&/g')"

f="$(mktemp)"
url="https://gist.githubusercontent.com/deekayen/4148741/raw/98d35708fa344717d8eee15d11987de6c8e26d7d/1-1000.txt"
curl -k -L -s "${url}" | egrep "^[a-z]{1,4}$" > "${f}"

wordcheck_sdcv() {
  c="${1}"
  t="$(echo ${2} | sed -e 's/\b\(.\)/\u\1/g')"
  m=$(sdcv -e -n "${t}" 2>/dev/null | grep -Fwci "${c}")
  if [ ! -z "${m}" ] && [ ${m} -gt 0 ]
  then
    echo "${t}"
  fi
}
export -f wordcheck_sdcv

wordcheck_dict() {
  c="${1}"
  t="${2}"
  m=$(dict "${t}" 2>/dev/null | grep -Fwci "${c}")
  if [ ! -z "${m}" ] && [ ${m} -gt 0 ]
  then
    echo "${t}"
  fi
}
export -f wordcheck_dict

find_sdcv() {
  echo "${clues}" | tr " " "\n" | grep -Fwv -f "${f}" | while read clue
  do
    for i in n v a r; do wn "${clue}" -syns${i} 2>/dev/null; done | grep -B1 '=>' | grep -v '\-\-' | \
    sed -e 's/.*=> //g' -e 's/, /\n/g' | grep -E '^\s*\S+\s*$' | sort -u | while read c1
    do
      grep -E "^${pattern}$" "${d}" | egrep -v "[']" | \
      xargs -n1 -P$(grep -c proc /proc/cpuinfo) bash -c 'wordcheck_sdcv $@' _ "${c1}" 2>/dev/null
    done
  done | sort | uniq -c | sort -k1rn | head -100 | awk '{print $NF}'
}
export -f find_sdcv

find_dict() {
  echo "${clues}" | tr " " "\n" | grep -Fwv -f "${f}" | while read clue
  do
    for i in n v a r; do wn "${clue}" -syns${i} 2>/dev/null; done | grep -B1 '=>' | grep -v '\-\-' | \
    sed -e 's/.*=> //g' -e 's/, /\n/g' | grep -E '^\s*\S+\s*$' | sort -u | while read c1
    do
      for ((i = 0; i < ${#a[@]}; i++)) ; do echo "${a[$i]}" ; done | egrep -v "[']" | sed -e "s/\b\(.\)/\u\1/g" | \
      xargs -n1 -P$(grep -c proc /proc/cpuinfo) bash -c 'wordcheck_dict $@' _ "${c1}" 2>/dev/null
    done
  done | sort | uniq -c | sort -k1rn | head -10 | awk '{print $NF}'
}
export -f find_dict

echo "Step 1 of 2: Matching clues to pattern ${pattern} using sdcv. This may take a while..."
unset a; mapfile -t a < <( find_sdcv )

echo "Step 2 of 2: Matching clues to pattern ${pattern} using dict. This may take a while..."
find_dict | while read a
do
  s="$(for i in n v a r; do wn "${a}" -syns${i} 2>/dev/null; done | grep -B1 '=>' | grep -v '\-\-' | \
  sed -e 's/.*=> //g' -e 's/, /, /g' | sed 's/$/,/g' | xargs | sed 's/,$//g')"
  echo "${a}:@${s}"
done | column -s'@' -t | egrep --color '^[[:alpha:]]{1,}\b|'
