#!/bin/bash
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                           igor@comradegeneral.com
#                                 2017-06-10
# ----------------------------------------------------------------------------
# A script to use rsync to copy complex directory structures, starting several
# levels below the parent source directory and running multiple rsync threads
# at the same time to utilize the available bandwidth.
# ----------------------------------------------------------------------------
IFS=$(echo -en "\n\b")

usage() {
cat << EOF
Syntax:
---------------------
rsync-parallel -o <rsync options; default: -aKPHAXx> -d <branch-out depth> -s <source_dir> -t <target_dir>

Example:
---------------------
rsync-parallel -d 3 -s /mnt/source -t /mnt/target
EOF
exit 1
}

while getopts ":s:t:d:o:" OPTION; do
	case "${OPTION}" in
		s)
			source_dir="${OPTARG}"
			;;
		t)
			target_dir="${OPTARG}"
			;;
		d)
			max_depth="${OPTARG}"
			;;
		o)
			rsync_options="${OPTARG}"
			;;
		\? ) echo "Unknown option: -$OPTARG" >&2; usage;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; usage;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; usage;;
	esac
done

if [ -z "${source_dir}" ]
then
	echo "Source directory must be specified"
	usage
fi

if [ -z "${target_dir}" ]
then
	echo "Target directory must be specified"
	usage
fi

if [ -z "${max_depth}" ]
then
	echo "Branch-out depth must be specified"
	usage
fi

if [ -z "${rsync_options}" ]
then
	rsync_options="aKHAXx"
fi

configure() {
    if [ "${source_dir}" == "${target_dir}" ] ; then echo "Source and target directories must not be the same! Exiting..." ; exit 1 ; fi
    if [ ${max_depth} -lt 2 ] ; then echo "Minimum search depth must be 2. Exiting..." ; exit 1 ; fi
    cpu_count=$(cat /proc/cpuinfo|grep processor | wc -l)
    let max_threads=cpu_count*30
    sleep_time=3
	
	
	export RSYNC="/usr/bin/rsync -${rsync_options}"

    randomnum=$(echo "`expr ${RANDOM}${RANDOM} % 1000000`+1"|bc -l)

    logdir="/var/log/rsync"
    if [ ! -d "${logdir}" ] ; then mkdir -p "${logdir}" ; fi
	cd "${logdir}"

    filelist="${logdir}/filelist_${randomnum}"
    if [ -f "${filelist}" ] ; then /bin/rm -f "${filelist}" ; fi

    split_prefix="${logdir}/filelist_split_${randomnum}_"
    /bin/rm -f ${split_prefix}*

    dirlist="${logdir}/dirlist_${randomnum}"
    if [ -f "${dirlist}" ] ; then /bin/rm -f "${dirlist}" ; fi

    tmplist="/${logdir}/tmplist_${randomnum}"
    if [ -f "${tmplist}" ] ; then /bin/rm -f "${tmplist}" ; fi

    level_min=$(echo "${source_dir}" | awk -F'/' '{print NF}')
    let level_max=level_min+max_depth-1

    logfile=${logdir}/`echo ${source_dir} | awk -F'/' '{print $NF}'`_`date +'%Y-%m-%d'`_${randomnum}_log.txt
    if [ -f "${logfile}" ] ; then /bin/rm -f "${logfile}" ; fi

    logfile_files=${logdir}/`echo ${source_dir} | awk -F'/' '{print $NF}'`_`date +'%Y-%m-%d'`_files_${randomnum}_log.txt
    if [ -f "${logfile_files}" ] ; then /bin/rm -f "${logfile_files}" ; fi

}

build_dir_list() {
    echo "`date +'%Y-%m-%d %H:%M:%S'`    Looking for directories ${max_depth} levels deep from ${source_dir}" >> "${logfile}"
    find "${source_dir}" -maxdepth ${max_depth} -mindepth 1 -mount -type d > "${dirlist}"
    touch "${tmplist}"

    echo "`date +'%Y-%m-%d %H:%M:%S'`    Pruning directory list. This may take a while..." >> "${logfile}"
    echo "Level max: $level_max"
    sort -r "${dirlist}" | while read dir
    do
        level=$(echo "${dir}" | awk -F'/' '{print NF}')
        if [ ${level} -eq ${level_max} ]
        then
            echo "$level ${dir}"
            echo "${dir}" >> "${tmplist}"
        elif [ ${level} -gt ${level_min} ] && [ ${level} -lt ${level_max} ] && [ `grep -c "^${dir}/" "${tmplist}"` -eq 0 ]
        then
            echo "$level ${dir}"
            echo "${dir}" >> "${tmplist}"
        fi
    done
    sed "s@${source_dir}/@@g" < "${tmplist}" | sort > "${dirlist}"
}

build_file_list() {
    echo "`date +'%Y-%m-%d %H:%M:%S'`    Looking for orphaned files" >> "${logfile}"
    exclude_list=$(grep -v "\/" "${dirlist}" | sed 's@ @\\s@g' | awk -F'/' '{print "-not -path */"$1"/*"}' | sort | uniq)
    max_depth_file=$(awk -F'/' '{print NF}' < $dirlist | sort -n | tail -1)
    find "${source_dir}" -maxdepth ${max_depth_file} -mount -type f `eval echo ${exclude_list}` -prune 2>/dev/null | sed "s@${source_dir}@\.@g" > "${filelist}"
}

report() {
    dircount=$(cat "${dirlist}" | grep -c .)
    filecount=$(cat "${filelist}" | grep -c .)
    echo "`date +'%Y-%m-%d %H:%M:%S'`    Found ${dircount} directories ${max_depth} levels deep and ${filecount} orphaned files" >> "${logfile}"
}

copy_files() {
    if [ -f "${filelist}" ]
    then
        if [ `grep -c . "${filelist}"` -gt 0 ]
        then
            if [ `grep -c . "${filelist}"` -gt 2000 ]
            then
                let lines=`grep -c . "${filelist}"`/20
                split -l ${lines} -a 10 -d "${filelist}" "${split_prefix}"
                k=1 ; find "${logdir}" -mount -type f -name "${split_prefix}[0-9]*" | while read filelist_split
                do
                    echo "`date +'%Y-%m-%d %H:%M:%S'`    Copying `wc -l ${filelist_split} | awk '{print $1}'` orphaned files found in ${filelist_split}" >> "${logfile}"
                    eval ${RSYNC} \
                            --log-file="${logfile_files}_${k}" \
                            --files-from="${filelist_split}" "${source_dir}/" "${target_dir}/" &disown
                    (( k = k + 1 ))
                done
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'`    Copying `wc -l ${filelist} | awk '{print $1}'` orphaned files" >> "${logfile}"
                eval ${RSYNC} \
                            --log-file="${logfile_files}" \
                            --files-from="${filelist}" "${source_dir}/" "${target_dir}/" &disown
            fi
        fi
    fi
}

copy_directories() {
    threads=1
    i=1
    cat "${dirlist}" | grep . | while read subfolder
    do
        if [ ! -d "${target_dir}/${subfolder}" ]
        then
            echo "Creating target subfolder: ${target_dir}/${subfolder}" >> "${logfile}"
            mkdir -p "${target_dir}/${subfolder}"
            chown --reference="${source_dir}/${subfolder}" "${target_dir}/${subfolder}"
            chmod --reference="${source_dir}/${subfolder}" "${target_dir}/${subfolder}"
        else
            echo "Target subfolder already exists: ${target_dir}/${subfolder}" >> "${logfile}"
        fi
        if [ ${threads} -le ${max_threads} ]
        then
            echo "`date +'%Y-%m-%d %H:%M:%S'`    Processing ${i} of ${dircount}: ${subfolder}" >> "${logfile}"
            eval ${RSYNC} --exclude .etc/ \
                        "${source_dir}/${subfolder}/" "${target_dir}/${subfolder}/" &disown
            let threads=threads+1
        else
            while [ `/bin/ps -ef | grep -v "[t]ar " | grep -v grep | grep -c "[r]sync "` -gt ${max_threads} ]
            do
                sleep ${sleep_time}
            done
            threads=1
            echo "`date +'%Y-%m-%d %H:%M:%S'`    Processing ${i} of ${dircount}: ${subfolder}" >> "${logfile}"
            eval ${RSYNC} \
                        "${source_dir}/${subfolder}/" "${target_dir}/${subfolder}/" &disown
            let threads=threads+1
        fi
        let i=i+1
    done
}

# RUNTIME

configure
build_dir_list
build_file_list
report
copy_files
copy_directories
