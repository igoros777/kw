#!/bin/bash

r_script="/var/adm/bin/test01.r"
r_script_url="https://raw.githubusercontent.com/igoros777/kw/master/test01.r"

if [ ! -f "${r_script}" ]
then
	echo "Download ${r_script_url} and save it to ${r_script}"
	exit 1
fi

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

re='^-[0-9]{1,}$'
h="-------,----,---------,------,---------,------,---------,--------"
rule () {
	printf -v _hr "%*s" $(tput cols) && echo ${_hr// /${1--}}
}
url="https://github.com/CSSEGISandData/COVID-19/tree/master/csse_covid_19_data/csse_covid_19_daily_reports"
url_raw="https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports"

if [ -z "${countries}" ]
then
	echo "You need to specify country code. Exiting..."
	exit 1010
fi

curl_get() {
	curl -s0 -k "${url_raw}/${e}.csv" 2>/dev/null | grep -vE "404: Not Found" | awk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' > "${tmpfile}"
}

rulem ()  {
	if [ $# -eq 0 ]; then
		echo "Usage: rulem MESSAGE [RULE_CHARACTER]"
		return 1
	fi
	printf -v _hr "%*s" $(tput cols) && echo -en ${_hr// /${2--}} && echo -e "\r\033[2C$1"
}

tmpfile="$(mktemp)"
tmpfootnotes="$(mktemp)"

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

for ((i = 0; i < ${#countries[@]}; i++))
do
	tmp_country="$(mktemp)"
	tmp_country2="$(mktemp)"
	tmp_country_name="$(mktemp)"
	for em in $(seq 0 28)
	do
		e="$(date -d"-${em} days" +'%m-%d-%Y')"
		curl_get
		c="${countries[$i]}"
		c="$(echo ${c} | sed 's/^ //g')"

		case ${c} in
			US) echo -e "* ${c} recovery rates are no longer tracked as of 2020-12-14" >> "${tmpfootnotes}" ;;
		esac

		echo "${c}" > "${tmp_country_name}"
		country_field=$(awk -F, 'NR==1{for(i=1;i<=NF;i++)if($i~/Country.Region/)f[n++]=i}{for(i=0;i<n;i++)printf"%s%s",i?" ":"",f[i];print""}' "${tmpfile}" 2>/dev/null | sort -u | head -1)
		confirmed_field=$(awk -F, 'NR==1{for(i=1;i<=NF;i++)if($i~/Confirmed/)f[n++]=i}{for(i=0;i<n;i++)printf"%s%s",i?" ":"",f[i];print""}' "${tmpfile}" 2>/dev/null | sort -u | head -1)
		deaths_field=$(awk -F, 'NR==1{for(i=1;i<=NF;i++)if($i~/Deaths/)f[n++]=i}{for(i=0;i<n;i++)printf"%s%s",i?" ":"",f[i];print""}' "${tmpfile}" 2>/dev/null | sort -u | head -1)
		recovered_field=$(awk -F, 'NR==1{for(i=1;i<=NF;i++)if($i~/Recovered/)f[n++]=i}{for(i=0;i<n;i++)printf"%s%s",i?" ":"",f[i];print""}' "${tmpfile}" 2>/dev/null | sort -u | head -1)
		if [ ! -z "${country_field}" ] && [ ! -z "${confirmed_field}" ] && [ ! -z "${deaths_field}" ] && [ ! -z "${recovered_field}" ]
		then
			confirmed=$(awk -F, -v c="$c" -v field=$country_field '$field == c' "${tmpfile}" | awk -v field=$confirmed_field -F, '{s+=$field}END{print s}')
			deaths=$(awk -F, -v c="$c" -v field=$country_field '$field == c' "${tmpfile}" | awk -v field=$deaths_field -F, '{s+=$field}END{print s}')
			recovered=$(awk -F, -v c="$c" -v field=$country_field '$field == c' "${tmpfile}" | awk -v field=$recovered_field -F, '{s+=$field}END{print s}')
			if [ ! -z "${confirmed}" ] && [ ! -z "${deaths}" ] && [ ${confirmed} -ne 0 ] && [ ${deaths} -ne 0 ]
			then
				death_pct="$(echo "scale=1;(${deaths}*100)/${confirmed}"| bc -l 2>/dev/null)"
			else
				death_pct='-'
			fi
			if [ ! -z "${confirmed}" ] && [ ! -z "${recovered}" ] && [ ${confirmed} -ne 0 ] && [ ${recovered} -ne 0 ]
			then
				recovery_pct="$(echo "scale=1;(${recovered}*100)/${confirmed}"| bc -l 2>/dev/null)"
			else
				recovery_pct='-'
			fi
			if [ ! -z "${confirmed}" ] && [ ! -z "${deaths}" ] && [ ! -z "${deaths}" ] && [ ${confirmed} -ne 0 ] && [ ${recovered} -ne 0 ] && [ ${deaths} -ne 0 ]
			then
				active_cases="$(echo "scale=0;${confirmed}-(${deaths}+${recovered})"| bc -l 2>/dev/null)"
			else
				active_cases='-'
			fi
			echo "${c},${e},${confirmed},${deaths},${recovered},${active_cases},${death_pct}%,${recovery_pct}%"
		fi
	done | tee >(awk -F, '{print $2","$3","$4","$5}' > "${tmp_country}")

	# ---------------------------------
	d28b="$(date -d'now -28 days' +'%m-%d-%Y')"
	reported_infected_28b="$(egrep "^${d28b}," "${tmp_country}" | awk -F, '{print $2}')"
	reported_dead_28b="$(egrep "^${d28b}," "${tmp_country}" | awk -F, '{print $3}')"
	reported_recovered_28b="$(egrep "^${d28b}," "${tmp_country}" | awk -F, '{print $4}')"
	if [ -z "${reported_infected_28b}" ]; then reported_infected_28b=0; fi
	if [ -z "${reported_dead_28b}" ]; then reported_dead_28b=0; fi
	if [ -z "${reported_recovered_28b}" ]; then reported_recovered_28b=0; fi
	# ---------------------------------

	d14b="$(date -d'now -14 days' +'%m-%d-%Y')"
	reported_infected_14b="$(egrep "^${d14b}," "${tmp_country}" | awk -F, '{print $2}')"
	reported_dead_14b="$(egrep "^${d14b}," "${tmp_country}" | awk -F, '{print $3}')"
	reported_recovered_14b="$(egrep "^${d14b}," "${tmp_country}" | awk -F, '{print $4}')"
	if [ -z "${reported_infected_14b}" ]; then reported_infected_14b=0; fi
	if [ -z "${reported_dead_14b}" ]; then reported_dead_14b=0; fi
	if [ -z "${reported_recovered_14b}" ]; then reported_recovered_14b=0; fi
	# ---------------------------------

	d7b="$(date -d'now -7 days' +'%m-%d-%Y')"
	reported_infected_7b="$(egrep "^${d7b}," "${tmp_country}" | awk -F, '{print $2}')"
	reported_dead_7b="$(egrep "^${d7b}," "${tmp_country}" | awk -F, '{print $3}')"
	reported_recovered_7b="$(egrep "^${d7b}," "${tmp_country}" | awk -F, '{print $4}')"
	if [ -z "${reported_infected_7b}" ]; then reported_infected_7b=0; fi
	if [ -z "${reported_dead_7b}" ]; then reported_dead_7b=0; fi
	if [ -z "${reported_recovered_7b}" ]; then reported_recovered_7b=0; fi
	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $2}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_infected_28b polynomial_infected_28b <<<$(${r_script} "${tmp_country2}" $(date -d'now -28 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_infected_28b} =~ ${re} ]] ; then linear_infected_28b=0; fi
	if [[ ${polynomial_infected_28b} =~ ${re} ]] ; then polynomial_infected_28b=0; fi
	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $3}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_dead_28b polynomial_dead_28b <<<$(${r_script} "${tmp_country2}" $(date -d'now -28 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_dead_28b} =~ ${re} ]] ; then linear_dead_28b=0; fi
	if [[ ${polynomial_dead_28b} =~ ${re} ]] ; then polynomial_dead_28b=0; fi
	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $4}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_recovered_28b polynomial_recovered_28b <<<$(${r_script} "${tmp_country2}" $(date -d'now -28 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_recovered_28b} =~ ${re} ]] ; then linear_recovered_28b=0; fi
	if [[ ${polynomial_recovered_28b} =~ ${re} ]] ; then polynomial_recovered_28b=0; fi
	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $2}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_infected_14b polynomial_infected_14b <<<$(${r_script} "${tmp_country2}" $(date -d'now -14 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_infected_14b} =~ ${re} ]] ; then linear_infected_14b=0; fi
	if [[ ${polynomial_infected_14b} =~ ${re} ]] ; then polynomial_infected_14b=0; fi

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $3}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_dead_14b polynomial_dead_14b <<<$(${r_script} "${tmp_country2}" $(date -d'now -14 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_dead_14b} =~ ${re} ]] ; then linear_dead_14b=0; fi
	if [[ ${polynomial_dead_14b} =~ ${re} ]] ; then polynomial_dead_14b=0; fi

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $4}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_recovered_14b polynomial_recovered_14b <<<$(${r_script} "${tmp_country2}" $(date -d'now -14 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_recovered_14b} =~ ${re} ]] ; then linear_recovered_14b=0; fi
	if [[ ${polynomial_recovered_14b} =~ ${re} ]] ; then polynomial_recovered_14b=0; fi
	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $2}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_infected_7b polynomial_infected_7b <<<$(${r_script} "${tmp_country2}" $(date -d'now -7 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_infected_7b} =~ ${re} ]] ; then linear_infected_7b=0; fi
	if [[ ${polynomial_infected_7b} =~ ${re} ]] ; then polynomial_infected_7b=0; fi

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $3}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_dead_7b polynomial_dead_7b <<<$(${r_script} "${tmp_country2}" $(date -d'now -7 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_dead_7b} =~ ${re} ]] ; then linear_dead_7b=0; fi
	if [[ ${polynomial_dead_7b} =~ ${re} ]] ; then polynomial_dead_7b=0; fi

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $4}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_recovered_7b polynomial_recovered_7b <<<$(${r_script} "${tmp_country2}" $(date -d'now -7 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)
	if [[ ${linear_recovered_7b} =~ ${re} ]] ; then linear_recovered_7b=0; fi
	if [[ ${polynomial_recovered_7b} =~ ${re} ]] ; then polynomial_recovered_7b=0; fi

	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $2}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_infected_7 polynomial_infected_7 <<<$(${r_script} "${tmp_country2}" $(date -d'now +7 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $3}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_dead_7 polynomial_dead_7 <<<$(${r_script} "${tmp_country2}" $(date -d'now +7 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $4}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_recovered_7 polynomial_recovered_7 <<<$(${r_script} "${tmp_country2}" $(date -d'now +7 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $2}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_infected_14 polynomial_infected_14 <<<$(${r_script} "${tmp_country2}" $(date -d'now +14 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $3}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_dead_14 polynomial_dead_14 <<<$(${r_script} "${tmp_country2}" $(date -d'now +14 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $4}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_recovered_14 polynomial_recovered_14 <<<$(${r_script} "${tmp_country2}" $(date -d'now +14 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	# ---------------------------------
	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $2}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_infected_28 polynomial_infected_28 <<<$(${r_script} "${tmp_country2}" $(date -d'now +28 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $3}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_dead_28 polynomial_dead_28 <<<$(${r_script} "${tmp_country2}" $(date -d'now +28 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

	echo "x,y" > "${tmp_country2}"
	cat "${tmp_country}" | while read line
	do
		d="$(echo $line | awk -F, '{print $1}' 2>/dev/null | sed 's/\-/\//g')"
		de="$(date -d"${d}" +'%s')"; value=$(echo ${line} | awk -F, '{print $4}' 2>/dev/null)
		echo "${de},${value}"
	done | sort -k1n | egrep -v ',0$' >> "${tmp_country2}"
	read -r linear_recovered_28 polynomial_recovered_28 <<<$(${r_script} "${tmp_country2}" $(date -d'now +28 days' +'%s') | egrep -v '^ +1 +$' | awk '{printf("%d\n",$0+=$0<0?-0.5:0.5)}' | xargs)

cat << EOF
# -----------------------------------------
# Projections -28 days for $(cat "${tmp_country_name}")
# -----------------------------------------
# Infected: ${linear_infected_28b}/${polynomial_infected_28b}/${reported_infected_28b} (Linear/Non-linear/Reported)
# Dead: ${linear_dead_28b}/${polynomial_dead_28b}/${reported_dead_28b} (Linear/Non-linear/Reported)
# Recovered: ${linear_recovered_28b}/${polynomial_recovered_28b}/${reported_recovered_28b} (Linear/Non-linear/Reported)
#
# -----------------------------------------
# Projections -14 days for $(cat "${tmp_country_name}")
# -----------------------------------------
# Infected: ${linear_infected_14b}/${polynomial_infected_14b}/${reported_infected_14b} (Linear/Non-linear/Reported)
# Dead: ${linear_dead_14b}/${polynomial_dead_14b}/${reported_dead_14b} (Linear/Non-linear/Reported)
# Recovered: ${linear_recovered_14b}/${polynomial_recovered_14b}/${reported_recovered_14b} (Linear/Non-linear/Reported)
#
# -----------------------------------------
# Projections -7 days for $(cat "${tmp_country_name}")
# -----------------------------------------
# Infected: ${linear_infected_7b}/${polynomial_infected_7b}/${reported_infected_7b} (Linear/Non-linear/Reported)
# Dead: ${linear_dead_7b}/${polynomial_dead_7b}/${reported_dead_7b} (Linear/Non-linear/Reported)
# Recovered: ${linear_recovered_7b}/${polynomial_recovered_7b}/${reported_recovered_7b} (Linear/Non-linear/Reported)
#
# -----------------------------------------
# Projections +7 days for $(cat "${tmp_country_name}")
# -----------------------------------------
# Infected: ${linear_infected_7}/${polynomial_infected_7} (Linear/Non-linear)
# Dead: ${linear_dead_7}/${polynomial_dead_7} (Linear/Non-linear)
# Recovered: ${linear_recovered_7}/${polynomial_recovered_7} (Linear/Non-linear)
#
# -----------------------------------------
# Projections +14 days for $(cat "${tmp_country_name}")
# -----------------------------------------
# Infected: ${linear_infected_14}/${polynomial_infected_14} (Linear/Non-linear)
# Dead: ${linear_dead_14}/${polynomial_dead_14} (Linear/Non-linear)
# Recovered: ${linear_recovered_14}/${polynomial_recovered_14} (Linear/Non-linear)
#
# -----------------------------------------
# Projections +28 days for $(cat "${tmp_country_name}")
# -----------------------------------------
# Infected: ${linear_infected_28}/${polynomial_infected_28} (Linear/Non-linear)
# Dead: ${linear_dead_28}/${polynomial_dead_28} (Linear/Non-linear)
# Recovered: ${linear_recovered_28}/${polynomial_recovered_28} (Linear/Non-linear)
# -----------------------------------------
#
EOF
/bin/rm -f "${tmp_country}" "${tmp_country2}" "${tmp_country_name}" 2>/dev/null
done | (echo -e "COUNTRY,DATE,CONFIRMED,DEATHS,RECOVERED,ACTIVE,MORTALITY,RECOVERY\n${h}" && cat) | column -s',' -t | sed '/^#/ s/ \{1,\}/ /g'

if [ -s "${tmpfootnotes}" ]
then
	cat << EOF

$(rulem FOOTNOTES)
$(cat "${tmpfootnotes}")

EOF
fi

/bin/rm -f "${tmpfile}" "${tmpfootnotes}" 2>/dev/null
