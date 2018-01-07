#!/bin/bash
#		              |
#             ___/"\___
#		  __________/ o \__________
#		    (I) (G) \___/ (O) (R)
#		         2016-12-22
# ----------------------------------------------------------------------------
# Salt wrapper for rsync-time-backup
# https://github.com/laurent22/rsync-time-backup
# ----------------------------------------------------------------------------
#
configure() {
    url="https://raw.githubusercontent.com/laurent22/rsync-time-backup/master/rsync_tmbackup.sh"
	this_host=`/bin/hostname | awk -F'.' '{print $1}'`
	if [ $(grep -c "^prod" <<<${this_host}) -eq 1 ] || [ "${this_host}" == "amidala" ]
	then
		nashost="prodnas01.krazyworks.com.local"
		nasshare="/nfspool_prod"
	else
		nashost="devqanas01.krazyworks.com.local"
		nasshare="/nfspool_devqa"
	fi
	mountdir="/nfspool"
	backupdir="rsync_time_backup"
    basedir="/var/adm/bin"
    if [ ! -d "${basedir}" ] ; then mkdir -p "${basedir}" ; fi
	this_time=$(date +'%Y-%m-%d %H:%M:%S')
	this_time_epoch=$(date -d "`echo ${this_time}`" "+%s")
    rsyncbackup="${basedir}/rsync_tmbackup.sh"
    if [ ! -x "${rsyncbackup}" ] || [ ! -s "${rsyncbackup}" ]
    then
        wget --no-check-certificate -O "${rsyncbackup}" "${url}" 2>/dev/null
        chmod 755 "${rsyncbackup}" 2>/dev/null
    fi
}

verify() {

	if [ ! -x "${rsyncbackup}" ]
	then
		echo "Rsync backup script ${rsyncbackup} not found. Exiting..."
		exit 1
	fi

	if [ ! -d "${mountdir}" ]
    then
        mkdir -p "${mountdir}"
    fi

    if [ `which mountpoint >/dev/null 2>&1 ; echo $?` -eq 0 ]
	then
		mountstatus=$(/bin/mountpoint "${mountdir}" >/dev/null 2>&1 ; echo $?)
		if [ ${mountstatus} -ne 0 ]
		then
			mount "${nashost}:${nasshare}" "${mountdir}"
			mountstatus=$(/bin/mountpoint "${mountdir}" >/dev/null 2>&1 ; echo $?)
			if [ ${mountstatus} -ne 0 ]
			then
				echo "Destination ${mountdir} is not mounted. Exiting..."
				exit 1
			fi
		fi
		else
		if [ `df "${mountdir}" | grep -c ${nashost}` -eq 0 ]
		then
			mount "${nashost}:${nasshare}" "${mountdir}"
			if [ `df "${mountdir}" | grep -c ${nashost}` -eq 0 ]
			then
				echo "Destination ${mountdir} is not mounted. Exiting..."
				exit 1
			fi
		fi
	fi

	if [ ! -d "${mountdir}/${backupdir}" ]
	then
		echo "Destination folder ${mountdir}/${backupdir} not found on ${nashost}. Exiting..."
		exit 1
	fi

	if [ ! -d "${mountdir}/${backupdir}/${this_host}" ]
    then
        mkdir -p "${mountdir}/${backupdir}/${this_host}"
    fi

	if [ ! -f "${mountdir}/${backupdir}/${this_host}/backup.marker" ]
    then
        touch "${mountdir}/${backupdir}/${this_host}/backup.marker"
    fi
}

do_backup() {
    egrep -i "ext[234]|reiserfs|jfs|xfs" /etc/fstab | awk '{print $2}' | while read line
    do
        if [ $(mountpoint "${line}" > /dev/null 2>&1 ; echo $?) -eq 0 ]
        then
            echo "Starting backup of ${this_host}:${line} to ${nashost}:${nasshare}/${backupdir}/${this_host}${line}/"
            if [ "${line}" == "/" ]
            then

                sleep 2
            else
                nohup ${rsyncbackup} ${line} "${mountdir}/${backupdir}/${this_host}${line}/" </dev/null >/dev/null 2>&1 &
            fi
        fi
    done
}

do_check() {
	if [ -f "${mountdir}/${backupdir}/${this_host}/backup.inprogress" ]
    then
        echo "Another backup is already in progress. Exiting..."
		exit 1
    fi
}

# RUNTIME
configure
verify
do_check
do_backup
