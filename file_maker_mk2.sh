#!/bin/bash
z="${1}"; c="${2}"
[[ -z "${z}" ]] && z=1000; [[ -z "${c}" ]] && c=3000
x="csv doc docx dotx gif gpg jpg odt pdf png pptx pst rtf vsd vsdx vss vst xls xlsm xlsx zip"
li="$(($((1 + $RANDOM % 4)) * $((10 + $RANDOM % ${z})) * $((10 + $RANDOM % ${z})) * $((10 + $RANDOM % ${z}))))"
lf="$((512 + $RANDOM % ${c}))"

w="$(mktemp)"
w_url="https://gist.githubusercontent.com/igoros777/05c41faeafcfc28c1376cab609824eb9/raw/10514d06e45ba183bf1e353793e3bbc5f70645be/aspell_dictionary.txt"
timeout 5 curl --max-time 4 -s0 -l -k "${w_url}" | grep -v "'" > ${w} || exit 1
m="$(mktemp)"
m_url="https://raw.githubusercontent.com/igoros777/kw/master/extensions.json"
timeout 5 curl --max-time 4 -s0 -l -k "${m_url}" | grep -v "'" > ${m} || exit 1

rnd() {
  e="$(echo "${x}" | xargs -n1 | shuf -n1)"
  f="$(shuf -n $((1 + $RANDOM % 4)) "${w}" | xargs | sed 's/ /_/g')$(if (( RANDOM % 2 )); then if (( RANDOM % 2 )); then echo "_$((1 + $RANDOM % 100))"; else echo "_$(date +'%Y-%m-%d')"; fi; fi).${e}"
  s=$((512 + $RANDOM % 100000))
  d="$(jq -r ".${e}.signs[]" "${m}" | head -1 | awk -F, '{print $2}')"
  o="$(jq -r ".${e}.signs[]" "${m}" | head -1 | awk -F, '{print $1}')"
}

xxdp() {
  xxd -p "${f}" | sed -e "0,/^/s//$d/" | sed -r "0,/.{${#d}}$/s///" | xxd -r -p | sponge "${f}"
}

rdd() {
  dn="$(shuf -n $((1 + $RANDOM % 2)) "${w}" | xargs | sed 's/ /_/g')$(if (( RANDOM % 2 )); then if (( RANDOM % 2 )); then echo "_$((1 + $RANDOM % 100))"; else echo "_$(date +'%Y-%m-%d')"; fi; fi)"
  echo "${dn}"
}

i=0; j=0;
while [[ ${i} -le ${li} ]] && [[ ${j} -le ${lf} ]]; do
  rnd && fallocate -l ${s} "${f}" && xxdp && (( i = i + $(stat --printf="%s" "${f}") )) && (( j = j + 1 ))
  echo -ne "${j}/${lf}"'\r'
done

/bin/rm -f ".txt"
mkdir -p {$(rdd),$(rdd),$(rdd)}/{$(rdd),$(rdd),$(rdd)}/{$(rdd),$(rdd),$(rdd)}
dl="$(find . -type d)"
find . -mindepth 1 -maxdepth 1 -type f | while read f; do
  /bin/mv "${f}" "$(shuf -n1 <<<"${dl}")"/ 2>/dev/null
done

for i in $(seq 1 3); do find . -type d -empty -delete; done
/bin/rm -f "${w}" "${m}"
