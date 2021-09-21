#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                             www.krazyworks.com
#                                 2016-08-03
# ----------------------------------------------------------------------------
# Record atop output in the background for future analysis
# ----------------------------------------------------------------------------

usage() {
cat << EOF
Syntax:
---------------------
atoplog -d <duration_minutes> [-t "<time when to run>" Default: in a minute] [-i <interval_seconds> Default: 5] [-w <target_directory> Default: /var/log/atop]

Example:
---------------------
atoplog -t "2:30pm today" -d 30 -i 2 -w /var/tmp/atop
EOF
exit 1
}

atop_check() {
	if [ ! -x /usr/bin/atop ]
	then
		echo "Can't find /usr/bin/atop. Exiting..."
		exit 1
	fi
	
	if [ ! -x /usr/bin/timeout ]
	then
		echo "Can't find /usr/bin/timeout. Exiting..."
		exit 1
	fi
	
	if [ $(ps -ef | egrep -c "[a]top\w[1-9].*log") -ne 0 ]
	then
		echo "Just FYI, there's another atop already running:"
		ps -ef | egrep "[a]top\w[1-9].*log"
	fi
}

while getopts ":d:t:i:w:" OPTION; do
	case "${OPTION}" in
		d)
			duration_minutes="${OPTARG}"
			;;
		t)
			when_to_run="${OPTARG}"
			;;
		i)
			interval_seconds="${OPTARG}"
			;;
		w)
			logdir="${OPTARG}"
			;;
		\? ) echo "Unknown option: -$OPTARG" >&2; usage;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; usage;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; usage;;
	esac
done

configure() {
	if [ -z "${duration_minutes}" ] ; then usage ; fi
	if [ -z "${when_to_run}" ] ; then when_to_run="now" ; fi
	datetime="$(date -d "${when_to_run}" +'%Y-%m-%d_%H%M%S')"
	if [ -z "${interval_seconds}" ] ; then interval_seconds=5 ; fi
	if [ -z "${logdir}" ] ; then logdir="/var/log/atop" ; fi
	if [ ! -d "${logdir}" ] ; then mkdir -p "${logdir}" ; fi
	outfile="${logdir}/atop_${datetime}.log"
	if [ -f "${outfile}" ] ; then /bin/rm -f "${outfile}" ; fi
	(( duration_seconds = duration_minutes * 60 ))
	(( duration_samples = duration_seconds / interval_seconds ))
	
}

atop_do() {
	at ${when_to_run} <<<"atop ${interval_seconds} ${duration_samples} -w ${outfile}"
	echo "Running atop at $(atq 2>/dev/null | tail -1 | awk '{print $2,$3}') for ${duration_minutes} minutes at ${interval_seconds}-second intervals with output saved to ${outfile}"
}

atop_help() {
cat << EOF

  You can read this file like so: atop -r ${outfile}
 --------------------------------------------------------------------------------------------------
|                                                                                                  |
| You access this file at any time: no need to wait for recording to finish.                       |
|                                                                                                  |
| Here are some of the useful filtering options:                                                   |
|                                                                                                  |
|  t - Skip forward in time to next snapshot                                                       |
|  T - Skip back in time to previous snapshot                                                      |
|  P - Filter by process name regex                                                                |
|  U - Filter by username regex                                                                    |
|  b - [hh:mm] - jump to specified timestamp                                                       |
|  r - skip back to start of file with current filter applied                                      |
|                                                                                                  |
| For more help, press "?" in atop                                                                 |
|                                                                                                  |
 --------------------------------------------------------------------------------------------------
 
EOF
}

# RUNTIME
atop_check
configure
atop_do
atop_help