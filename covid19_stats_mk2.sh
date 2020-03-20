#!/bin/bash

while getopts ":c:" opt
do
	case ${opt} in
		c  ) countries+=("${OPTARG}") ;;
		\? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
:  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
*  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
	esac
done
shift $((OPTIND -1))

url="https://github.com/CSSEGISandData/COVID-19/tree/master/csse_covid_19_data/csse_covid_19_daily_reports"
url_raw="https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports"

if [ -z "${countries}" ]
then
	echo "You need to specify country code. Exiting..."
	exit 1010
fi

curl_get() {
	curl -s0 -k "${url_raw}/${e}.csv" 2>/dev/null | grep -vE "404: Not Found" > "${tmpfile}"
}

tmpfile="$(mktemp)"
e="$(date +'%m-%d-%Y')"
curl_get
if [ ! -s "${tmpfile}" ]
then
	e="$(date -d'-1 days' +'%m-%d-%Y')"
	curl_get
fi
if [ ! -s "${tmpfile}" ]
then
	echo "Unable to download CSV file. Exiting..."
	exit 1030
fi
if [ ! -s "${tmpfile}" ]
then
	e="$(date -d'-1 days' +'%m-%d-%Y')"
	curl_get
fi

for ((i = 0; i < ${#countries[@]}; i++))
do
	c="${countries[$i]}"
	c="$(echo ${c} | sed 's/^ //g')"
	confirmed=$(awk -F, -v c="$c" '$2 == c' "${tmpfile}" | awk -F, '{s+=$4}END{print s}')
	deaths=$(awk -F, -v c="$c" '$2 == c' "${tmpfile}" | awk -F, '{s+=$5}END{print s}')
	recovered=$(awk -F, -v c="$c" '$2 == c' "${tmpfile}" | awk -F, '{s+=$6}END{print s}')
	death_pct="$(echo "scale=1;(${deaths}*100)/${confirmed}"|bc -l)"
	recovery_pct="$(echo "scale=1;(${recovered}*100)/${confirmed}"|bc -l)"
	active_cases="$(echo "scale=0;${confirmed}-(${deaths}+${recovered})"|bc -l)"
	echo "${c},${e},${confirmed},${deaths},${recovered},${active_cases},${death_pct}%,${recovery_pct}%"
done | (echo "COUNTRY,DATE,CONFIRMED,DEATHS,RECOVERED,ACTIVE,MORTALITY,RECOVERY" && cat) | column -s',' -t
/bin/rm -f "${tmpfile}" 2>/dev/null
