#!/bin/bash
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2017-11-14
#
configure() {
	this_time=$(date +'%Y-%m-%d_%H%M%S')
	# WP home folder
	wph=/opt/wp/html/wp
	# WP export target folder
	e=/opt/wp/wp_export
	# wp2md target folder
	w=/opt/wp/wp2md/${this_time}
	mkdir -p ${w}
	# Sharepoint upload URL
	sp_url="https://sharepoint_host/path/Shared%20Documents/wp/autosync"
	# your Sharepoint login credentials
	DOMAIN=COMPANY
	USERNAME=jdoe
	PASSWORD="yourP@ssw0rd"
}

wp_export() {
	wp export \
	--path=${wph} \
	--dir=${e}/ \
	--post_type=post \
	--post_status=publish \
	--filename_format={site}_{date}.{n}.xml \
	--start_date=$(date -d "-2 days" +'%Y-%m-%d') --end_date=$(date +'%Y-%m-%d')
}

convert_md() {
	# Convert exported XML into markdown format
	for i in $(find ${e} -type f -name "*\.xml"); do
		wp2md -url -d ${w}/ ${i}
		/bin/rm -f ${i}
	done
}

convert_sp() {
	# Convert markdown files into DOCX and HTML
	# Strip date from filename to make sure the new version overwrites old version on Sharepoint
	for i in $(find ${w} -mindepth 2 -type f -name "*\.md"); do
		i_new="$(echo ${i} | awk -F'/' '{print $NF}' | sed -r 's/^[0-9]{8}-//g'| sed "s/\.md$/\.md/g")"
		/bin/mv "${i}" "${w}/posts/${i_new}"
		j="$(echo ${i} | awk -F'/' '{print $NF}' | sed -r 's/^[0-9]{8}-//g'| sed 's/\.md$/\.docx/g')"
		k="$(echo ${i} | awk -F'/' '{print $NF}' | sed -r 's/^[0-9]{8}-//g'| sed 's/\.md$/\.html/g')"
		pandoc -s "${w}/posts/${i_new}" -o "${w}/posts/${k}"
		pandoc -s "${w}/posts/${k}" -o "${w}/posts/${j}"
	done
}

sync_sp() {
	# Sync files to Sharepoint
	for extension in md docx html; do
		for i in $(find ${w} -mindepth 2 -type f -name "*\.${extension}"); do
		j="$(echo ${i} | awk -F'/' '{print $NF}' | sed -r 's/^[0-9]{8}-//g'| sed "s/\.md$/\.${extension}/g")"
		curl --ntlm --user ${DOMAIN}\\${USERNAME}:${PASSWORD} --upload-file "${w}/posts/${j}" "${sp_url}/${extension}/"
		done
	done
}

# RUNTIME
configure
wp_export
convert_md
convert_sp
sync_sp
