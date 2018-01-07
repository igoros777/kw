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
f="/var/log/boot.log"
if [ ! -r "${f}" ]
then
	echo "Cannot access ${f}"
	exit 1
fi

ouif="/var/tmp/oui.txt"
ouiurl="http://standards.ieee.org/regauth/oui/oui.txt"
howold=90

if [ ! -f "${ouif}" ] || test $(find "${ouif}" -mtime +${howold})
then
	echo "Downloading IEEE Organizationally Unique Identifier. This will take a few minutes..."
	wget -q -O "${ouif}" "${ouiurl}"
	if [ -f "${ouif}" ]
	then
		sed -i 's/\r$//g' "${ouif}"
	else
		echo "Cannot download ${ouiurl}"
		exit 1
	fi
fi

IFS=$'\n' ; op_array=($(grep -oP "DHCP[A-Z]{1,}" "${f}" | sort -u)) ; unset IFS
IFS=$'\n' ; mac_array=($(grep -oE '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' "${f}" | sort -u)) ; unset IFS
IFS=$'\n' ; ip_array=($(grep -oE "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})" "${f}" | sort -u)) ; unset IFS

s1=$(echo "scale=0;`printf '%s\n' ${op_array[@]} | wc -L`+1"|bc)

printf "%-18s %-16s %-8s %-20s" "MAC" "IP" "Status" "Manufacturer"
for ((i = 0; i < ${#op_array[@]}; i++)) ; do printf "%-${s1}s" "${op_array[$i]}" ; done
printf "\n"

printf '%s\n' ${mac_array[@]} | while read mac
do
	ip_address=$(tac "${f}" | grep -m1 "DHCPOFFER.*${mac}" | grep -oE "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})")
	if [ -z "${ip_address}" ] ; then ip_address="none" ; fi
	if [ $(ping -q -c 1 -W 5 ${ip_address} > /dev/null 2>&1 ; echo $?) -eq 0 ]
	then
		ip_online="up"
	else
		ip_online="down"
	fi
	oui=$(echo ${mac//[:.- ]/} | tr "[a-f]" "[A-F]" | egrep -o "^[0-9A-F]{6}")
	mfg="$(grep -m1 "^${oui}" "${ouif}" | cut -f3 -d$'\t' | cut -c1-18 | sed -e 's/,\.//g')"
	if [ -z "${mfg}" ]; then mfg="Unknown" ; fi
	printf "%-18s %-16s %-8s %-20s" "${mac}" "${ip_address}" "${ip_online}" "${mfg}"
	printf '%s\n' ${op_array[@]} | while read op
	do
		c=$(grep -cE "${op} .* ${mac} " "${f}")
		printf "%-${s1}s" ${c}
	done
	printf "\n"
done
