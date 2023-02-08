#!/bin/bash
# Use the output on https://www.gpsvisualizer.com/convert_input?convert_output=gpx
# to generate GPX file that can be loaded as a layer into a Google Map
infile="${1}"
[[ ! -f "${infile}" ]] && exit 1
/bin/cp -pf "${infile}" "${infile}_"
infile="${infile}_"
LANG=C sed -i 's/[\d128-\d255]//g' "${infile}"
awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' "${infile}" | sponge "${infile}"

export GOOGLE_MAPS_API_KEY="Get your Google Maps API key"
apiurl="https://maps.googleapis.com/maps/api/geocode/json"
${IFS+"false"} && unset oldifs || oldifs="$IFS"
IFS=,
tail -n +2 "${infile}" | while read line
do
  read -r v_start v_end v_place v_lat v_lon v_num v_ent_d v_ent_t v_exit_d v_exit_t v_hours v_hhmmss v_notes v_type v_uuid <<<"${line}"
  v_ent="$(date -d"${v_ent_d} ${v_ent_t}" +'%Y-%m-%d %H:%M:%S')"
  v_exit="$(date -d"${v_exit_d} ${v_exit_t}" +'%Y-%m-%d %H:%M:%S')"
  v_addr="$(curl -s "${apiurl}?latlng=${v_lat},${v_lon}&key=${GOOGLE_MAPS_API_KEY}" | jq -r '.results[].formatted_address' | \
  awk 'length==len {line=line ORS $0}; NR==1 || length>len {len=length; line=$0}; END {print line}' | head -1 | sed -r 's/( )?@( )?/ /g')"
  echo "\"${v_ent} - ${v_addr}\",${v_lat},${v_lon}"
done | (echo "name,latitude,longitude" && cat) | column -s',' -t
${oldifs+"false"} && unset IFS || IFS="$oldifs"
/bin/rm -f "${infile}"
