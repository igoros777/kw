#!/bin/bash
lim=1000
email="email@domain.com"
this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
time_db=$(date +'%Y-%m-%d %H:%M:%S')
lockfile="/tmp/${this_script}.lock"
logfile="/var/tmp/${this_script}.log"
this_host=$(echo ${HOSTNAME} | awk -F'.' '{print $1}')
 
pid=$(ps -ef | grep -m1 "[p]rocess_string" | awk '{print $2}')
c=$(netstat -tunap | grep -c ${pid})
 
echo -e "${time_db}\t${this_host}\t${pid}\t${c}" >> "${logfile}"
 
notify() {
	echo "process_string PID ${pid} has opened ${c} TCP connections on ${HOSTNAME}" | \
	mailx -s "process_string network alert from ${HOSTNAME}" "${email}"
	touch "${lockfile}"
}
 
if [ ${c} -gt ${lim} ]
then
	if [ -f "${lockfile}" ]
	then
		if [ $(echo $(( (`date +%s` - `stat -L --format %Y ${lockfile}`) < (24*60*60) ))) -eq 0 ]
		then
			notify
		fi
	else
		notify
	fi
fi
