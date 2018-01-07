#!/bin/bash
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                           igor@comradegeneral.com
#                                 2017-06-10
# If you accidentally lost your crontab and have no backups, this script
# may help recover crontab entries by analyzing the cron log. You will
# still need to interprete the recovered information and reconstruct
# the cron jobs the best you can.

clear
configure() {
	host=$(hostname -s)					# hostname as it appears in the cron log
	logdir="/var/log"					# directory containing the cron log
	cronlog="${logdir}/cron"			# cron log location
	cronuser="root"						# cron user name
	cron_type="CMD"						# cron log entry type
	exclude_string="sa\/sa|run-parts"	# exclude system cronjobs
	tmpdir="/tmp"						# temp directory
	# -------------------------------------------------------------------
	counter_diff_filename="unique_crons_counter.tmp"
    counter_diff_file="${tmpdir}/${counter_diff_filename}"
}

verify() {
	if [ ! -d "${tmpdir}" ] ; then mkdir -p "${tmpdir}"; fi

	if [ ! -r "${cronlog}" ]
	then
		echo "Cron log ${cronlog} not found. Exiting..." ; exit 1
	fi

	if [ -z ${host} ]
	then
		echo "Unable to determine host name. Exiting..." ; exit 1
	fi

	if [ `grep -c ^${cronuser}: /etc/passwd` -ne 1 ]
	then
		echo "Cron user ${cronuser} not found. Exiting..."
	fi

	if [ -f "${counter_diff_file}" ] ; then /bin/rm -f "${counter_diff_file}" ; fi
}

convert_time() {
    num=$1
    min=0 ; hour=0 ; day=0
    if((num>59));then
        ((sec=num%60)) ; ((num=num/60))
        if((num>59))
			then ((min=num%60)) ; ((num=num/60))
            if((num>23))
				then ((hour=num%24)) ; ((day=num/24))
				else ((hour=num))
            fi
			else ((min=num))
        fi
		else ((sec=num))
    fi
    echo "$day"d "$hour"h "$min"m "$sec"s
}

reconstruct() {
	jobid=1
	grep "${host}" "${cronlog}" | grep "(${cronuser})" | grep "${cron_type}" | sed -e 's/CROND\[[0-9]*\]: /\%/gI' | \
	awk -F'%' '{print $NF}' | sed -e "s/(${cronuser}) ${cron_type} (//g" -e 's/)$//g' | sort -u | egrep -v "${exclude_string}" | \
	while read jobname
	do
		if [ `grep -c "(${jobname}" "${cronlog}"` -ge 2 ]
		then
			i=0
			grep "(${jobname}" "${cronlog}" | tail -2 | awk '{print $1" "$2" "$3}' | while read timestamp
			do
				if [ ${i} -eq 0 ]
				then
					previous_timestamp_epoch=$(date -d "${timestamp}" "+%s") ; i=1
				elif [ ${i} -eq 1 ]
				then
					following_timestamp_epoch=$(date -d "${timestamp}" "+%s")
					timestamp_diff_epoch=$(echo "scale=0;${following_timestamp_epoch}-${previous_timestamp_epoch}" | bc -l)
					echo ${timestamp_diff_epoch} > "${counter_diff_file}"
					i=0
				fi
			done
			timediff=`cat "${counter_diff_file}"`
			last_run_timestamp=$(grep "${jobname}" "${cronlog}" | tail -1 | awk '{print $1" "$2" "$3}')
			cat << EOF
Job ID: ${jobid}
Job Last Run: ${last_run_timestamp}
Job Interval: ${timediff} (sec), or approximately every `convert_time ${timediff}`

Job Command:

${jobname}

----------------------------------------------------------


EOF
			(( jobid = jobid + 1 ))
		fi
	done
}

# RUNTIME

configure
verify
reconstruct
