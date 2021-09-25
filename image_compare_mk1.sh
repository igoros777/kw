#!/bin/bash
fromdir="${1}"
todir="${2}"
outfile="$(mktemp)"

fcount="$(find "${fromdir}" -type f -not -path "*/tmp/*" | wc -l)"
tcount="$(find "${todir}" -type f -not -path "*/tmp/*" | wc -l)"

mkdir -p "${fromdir}/tmp/"
mkdir -p "${todir}/tmp/"

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
for i in "${fromdir}" "${todir}"
do
  l=1
  echo "Resizing photos in ${i}"
  find "${i}" -type f -not -path "*/tmp/*" | while read f
  do
    if [ ! -f "${i}/tmp/$(filename "${f}")" ]
    then
      convert "${f}" -resize 150x150\> "${i}/tmp/$(filename "${f}")"
      touch -d @$(stat -c "%Y" "${f}") "${i}/tmp/$(filename "${f}")"
    fi
  done
done
IFS=$SAVEIFS

l=0; m=1
find "${fromdir}/tmp" -type f | while read f
do
  (( l = l + 1 ))
  find "${todir}/tmp" -type f -printf "%T@ %p\n" | sort -rn | awk '{for (i=2; i<=NF; i++) print $i}' | while read j
  do
    if [ "${f}" != "${j}" ]
    then
      printf -v numl "%0$(echo -n ${fcount}|wc -c)d" ${l}; printf -v numm "%0$(echo -n ${tcount}|wc -c)d" ${m}
      echo -ne "Comparing photo ${numl}/${fcount} to ${numm}/${tcount}\r"
      (( m = m + 1 ))
      v="$(convert "${f}" "${j}" -trim +repage -resize "150x150^!" -metric RMSE -format %[distortion] -compare info: 2>/dev/null)"
      if [[ ! -z "${v}" ]] && (( $(echo "${v} < 0.1" | bc -l) ))
      then
        echo "${f}^${j}" | sed 's@/tmp@@g' >> "${outfile}"
        m=1
        break
      fi
    fi
  done
done
echo -e "\n\n"
echo -e "Matching photos in ${outfile}:\n"
cat "${outfile}" | column -s'^' -t
echo -e "\n"
echo -e "Unique photos in ${fromdir}:\n"
sort -u <(comm -13 <(awk -F^ '{print $1}' "${outfile}" | sort) <(find "${fromdir}" -type f -not -path "*/tmp/*" | sort) | sed 's@/tmp@@g') \
<(awk -F^ '{print $1,$2}' "${outfile}" | xargs | sed 's/ /\n/g' | sort | uniq -c | grep '\b1\b' | awk '{for (i=2; i<=NF; i++) print $i}')
