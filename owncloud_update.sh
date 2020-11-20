#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                           igor@comradegeneral.com
#                                  2019-03-25
# ----------------------------------------------------------------------------
# Upgrade local installation of ownCloud
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-03-25  igor  wrote this script
# ----------------------------------------------------------------------------

function func_configure() {
  mustbe="root"                                 # privileged user to run this update; usually root
  httpd_user="apache"                           # user running the Web server process; usually apache or www-data
  httpd_group="apache"                          # primary group of the user running the Web server process; usually apache or www-data
  web_root="/data/htdocs/comradegeneral.com"    # path where current 'owncloud' folder is located
  owncloud_folder="owncloud"                    # name of the ownCloud folder; by default is 'owncloud'
  db_user="root"                                # database user
  db_host="localhost"                           # database server
  db_name="owncloud"                            # database name
  echo "Checking disk consumption for ${web_root}/${owncloud_folder}"
  space_required="$(du -sh ${web_root}/${owncloud_folder} | awk '{print $1}')"
  echo ""
  df -hP
  echo ""
  echo -n "Specify backup destination (needs at least ${space_required}): "
  read -a backup_dir
  echo ""
# ----------------------------------------------------------------------------
  this_time="$(date +'%Y-%m-%d_%H%M%S')"
  this_host="$(hostname | awk -F'.' '{print $1}')"
  tmpdir="$(mktemp -d)"
}

function func_checkuser() {
 # This function verifies that the script is running under the required user ID.
 if [ "$(whoami)" != "${mustbe}" ]
 then
  echo "Must be ${mustbe} to run this script. Exiting..."
  exit 90
 fi
}

function func_get_dbpass() {
  echo -n "Enter password for database user ${db_user}: "
  read -s db_pass
  echo ""
  if [ -z "${db_pass}" ]
  then
    echo "Database password cannot be null. Exiting..."
    exit 88
  fi
  MYSQL="/usr/bin/mysql --batch --skip-column-names --max_allowed_packet=100M -h${db_host} --port=${db_port} -u${db_user} -p${db_pass} ${db_name} -e"
  MYSQLDUMP="/usr/bin/mysqldump -u${db_user} -p${db_pass} ${db_name}"
}

function func_get_version() {
  echo -n "Enter ownCloud version to install (i.e. 10.1.0): "
  read owncloud_version
  echo ""
  if [ -z "${owncloud_version}" ]
  then
    echo "Application version cannot be null. Exiting..."
    exit 98
  fi
  owncloud_url="https://download.owncloud.org/community/owncloud-${owncloud_version}.tar.bz2"
  echo "Downloading ${owncloud_url}"
  curl --connect-timeout 5 -k -s0 -q "${owncloud_url}" > "${tmpdir}/owncloud-${owncloud_version}.tar.bz2"
  if [ ${?} -ne 0 ] || [ ! -f "${tmpdir}/owncloud-${owncloud_version}.tar.bz2" ] || [ $(/usr/bin/file "${tmpdir}/owncloud-${owncloud_version}.tar.bz2" | grep -c bzip2) -ne 1 ]
  then
    echo "Unable to download ${owncloud_url}. Exiting..."
    exit 99
  fi
}

function func_validate() {
  cd ~
  httpd_user_real="$(ps -ef | grep [h]ttpd | grep -v ^root | head -1 | awk '{print $1}')"
  if [ "${httpd_user}" != "${httpd_user_real}" ]
  then
    echo "You said httpd user is ${httpd_user}, but it seems to be ${httpd_user_real}. Exiting..."
    exit 103
  fi
  if [ ! -d "${web_root}" ]
  then
    echo "The specified web root location does not exist: ${web_root}. Exiting..."
    exit 105
  fi
  if [ ! -d "${web_root}/${owncloud_folder}" ]
  then
    echo "The specified ownCloud location does not exist: ${web_root}/${owncloud_folder}. Exiting..."
    exit 105
  fi
  db_check="$(${MYSQL} "show tables;" 2>/dev/null | grep -c comments)"
  if [ "${db_check}" -eq 0 ]
  then
    echo "Unable to work with database ${db_name}. Exiting..."
    exit 112
  fi
  if [ ! -d "${backup_dir}" ]
  then
    mkdir -p "${backup_dir}" 2>/dev/null
    if [ ! -d "${backup_dir}" ]
    then
      echo "Unable to create backup directory ${backup_dir}. Exiting..."
      exit 122
    fi
  else
    touch "${backup_dir}/.writecheck" 2>/dev/null
    if [ $? -ne 0 ]
    then
      echo "Unable to write to backup directory ${backup_dir}. Exiting..."
      exit 132
    else
      /bin/rm -f "${backup_dir}/.writecheck"
    fi
  fi
}

function func_backup_do() {
  echo "Backing up ${web_root}/${owncloud_folder} to ${backup_dir}/${owncloud_folder}_${this_time}/"
  rsync -aKx "${web_root}/${owncloud_folder}"/ "${backup_dir}/${owncloud_folder}_${this_time}"/ 2>/dev/null
  if [ ${?} -ne 0 ]
  then
    echo "Backup of ${web_root}/${owncloud_folder} failed. Exiting..."
    exit 142
  fi
  echo "Backing up database ${db_name} to ${backup_dir}/${db_name}_${this_time}.sql"
  ${MYSQLDUMP} > "${backup_dir}/${db_name}_${this_time}.sql" 2>/dev/null
  if [ ${?} -ne 0 ] || [ ! -f "${${backup_dir}/${db_name}_${this_time}.sql}" ]
  then
    echo "Backup of ${db_name} failed. Exiting..."
    exit 152
  fi
  echo "Compressing database backup ${backup_dir}/${db_name}_${this_time}.sql"
  gzip "${backup_dir}/${db_name}_${this_time}.sql"
}

function func_service_stop() {
  echo "Stopping Web server"
  /sbin/service httpd stop
  sleep 3
  if [ $(ps -ef | grep -c [s]bin/httpd) -gt 0 ]
  then
    echo "Unable to stop httpd. Exiting..."
    exit 203
  fi
  echo "Stopping cron daemon"
  /sbin/service crond stop
  sleep 3
  if [ $(ps -ef | grep -c [c]rond) -gt 0 ]
  then
    echo "Unable to stop crond. Exiting..."
    exit 205
  fi
}

function func_service_start() {
  echo "Starting Web server"
  /sbin/service httpd start
  sleep 3
  if [ $(ps -ef | grep -c [h]ttpd) -eq 0 ]
  then
    echo "Unable to start httpd!"
  fi
  echo "Starting cron daemon"
  /sbin/service crond start
  sleep 3
  if [ $(ps -ef | grep -c [c]rond) -eq 0 ]
  then
    echo "Unable to start crond!"
  fi
}

function func_enable_maintmode() {
  echo "Enabling maintenance mode"
  /usr/bin/sudo -u ${httpd_user} php "${web_root}/${owncloud_folder}/occ" maintenance:mode --on
}

function func_disable_maintmode() {
  echo "Disabling maintenance mode"
  /usr/bin/sudo -u ${httpd_user} php "${web_root}/${owncloud_folder}/occ" maintenance:mode --off
}

function func_upgrade_do() {
  echo "Enabling maintenance mode"
  func_enable_maintmode
  func_service_stop
  /bin/mv "${web_root}/${owncloud_folder}" "${web_root}/${owncloud_folder}_${this_time}"
  tar -jxf "${tmpdir}/owncloud-${owncloud_version}.tar.bz2" -C "${web_root}/" 2>/dev/null 1>&2
  if [ ${?} -ne 0 ]
  then
    echo "Unable to extract ${tmpdir}/owncloud-${owncloud_version}.tar.bz2. Putting everything back and exiting..."
    /bin/mv "${web_root}/${owncloud_folder}_${this_time}" "${web_root}/${owncloud_folder}"
    func_service_start
    sleep 3
    func_disable_maintmode
    exit 230
  fi
  echo "Setting ${web_root}/${owncloud_folder} ownership"
  chown -R ${httpd_user}:${httpd_group} "${web_root}/owncloud"
  /bin/mv "${web_root}/owncloud" "${web_root}/${owncloud_folder}" 2>/dev/null
  echo "Deleting new config and data folders"
  /bin/rm -rf "${web_root}/${owncloud_folder}/data" 2>/dev/null
  /bin/rm -rf "${web_root}/${owncloud_folder}/config" 2>/dev/null
  echo "Copying old config and data folders"
  /bin/mv "${web_root}/${owncloud_folder}_${this_time}/data" "${web_root}/${owncloud_folder}/"
  /bin/mv "${web_root}/${owncloud_folder}_${this_time}/config" "${web_root}/${owncloud_folder}/"
  func_service_start
  echo "Running ownCloud update"
  /usr/bin/sudo -u ${httpd_user} php "${web_root}/${owncloud_folder}/occ" upgrade
  func_disable_maintmode
}

function func_cleanup() {
  /bin/rm -rf "${tmpdir}" 2>/dev/null
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
func_configure
func_checkuser
func_get_dbpass
func_get_version
func_validate
func_backup_do
func_upgrade_do
func_cleanup
