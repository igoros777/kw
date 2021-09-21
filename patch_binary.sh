#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                krazyworks.com
#                                  2017-12-01

while getopts ":k:f:" opt
do
	case ${opt} in
		k)
			set -f
			IFS=' '
			array_k=(${OPTARG})
			;;
		f)
			set -f
			IFS=' '
			array_f=(${OPTARG})
			;;
		*)
			exit 1
			;;
	esac
done

if [ "${#array_k[@]}" -eq 0 ] || [ "${#array_f[@]}" -eq 0 ]
then
	exit 1
fi

time_set() {
	curdate=$(date) && date -s "${ctime}" >/dev/null 2>&1 && touch "${i}" && date -s "${curdate}" >/dev/null 2>&1
}

r="${RANDOM}"
for i in "${array_f[@]}"
do
	echo "${i}"
	if [ -f "${i}" ]
	then
		ctime=$(stat -c %z "${i}")
		for u in "${array_k[@]}"
		do
			strings ${i} | grep "${u}" | sort -u -r | while read os
			do
				ns="$(sed "s/${u}/$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w $(echo ${#u}) | head -n 1)/g" <<<"${os}")"
				osh="$(echo -n ${os} | xxd -g 0 -u -ps -c 256 | tr -d '\n')00"
				nsh="$(echo -n ${ns} | xxd -g 0 -u -ps -c 256 | tr -d '\n')00"
				hexdump -ve '1/1 "%.2X"' "${i}" | sed -r "s/${osh}/${nsh}/g" | xxd -r -p > "${i}_${r}"
				/bin/mv -f "${i}_${r}" "${i}"
			done
		done
		time_set
	fi
done
