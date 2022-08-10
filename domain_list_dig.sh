#!/bin/bash
list="${1}"
if [ ! -r "${list}" ]; then exit 1 ; fi
grep . "${list}" | awk -F. '{print $(NF-1)"."$NF}' | sort -u |
while read m
do
  egrep "${m}(\s|$)" "${list}" | sort -u | while read i
  do
    unset array_variables array_values
    levels=$(echo "${i}" | sed 's/[^.]//g' | awk '{ print length+1 }')
    array_variables=($(for j in $(seq 1 ${levels}); do echo s${j}ld; done))
    array_values=($(for l in $(seq ${levels} -1 1); do echo "${i}" | awk -F. -v f=${l} '{s = ""; for (i = f; i <= NF; i++) s = s$i " "; print s }' | sed 's/\s/./g' | sed 's/\.$//g'; done))
    for ((k = 0; k < ${#array_variables[@]}; k++))
    do
      eval "$(echo "${array_variables[$k]}")"="$(echo "\"${array_values[$k]}\"")"
    done
    dig ${i} @$(dig ns ${i} 2>/dev/null | \
    egrep -m1 "^${i}.*IN.(CNAME|NS)" | awk '{print $NF}' | \
    sed 's/\.$//g') -t any 2>/dev/null | grep -v \; | grep . | while read line
    do
      t=$(echo "${line}" | awk '{print $4}')
      r=$(echo "${line}" | awk '{print $1}')
      ttl=$(echo "${line}" | awk '{print $2}')
      v=$(echo "${line}" | awk '{print $NF}' | sed 's/\.$//g')
      echo "${i:-none},${s1ld:-none},${s2ld:-none},${s3ld:-none},${s4ld:-none},${t:-none},${ttl:-none},${v:-none}"
    done
  done
done | (echo "Record,TLD,SLD,3LD,4LD,Type,TTL,Value" && cat)
