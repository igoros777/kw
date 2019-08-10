#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2019-08-08
# ----------------------------------------------------------------------------
# Identify active system services that are not running and restart them.
# Tested with RHEL/CentOS 7
#
# Documentation URL: https://
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-08-08  igor  wrote this script
# ----------------------------------------------------------------------------

function func_configure() {
  # A list of services that should not be restarted even if they're not running
  exclude="rhel|abrt|mdmonitor|microcode|raid|systemd|ntpd|chrony"
  tmpfile="$(mktemp)"
  #
  this_host="$(hostname | awk -F. '{print $1}')"
  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
  this_script_full="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  this_time_db=$(date +'%Y-%m-%d %H:%M:%S')
  this_time_epoch=$(date -d "${this_time_db}" '+%s')
  this_time=$(date -d "${this_time_db}" +'%Y-%m-%d_%H:%M:%S')
  #
  logdirbase="/var/log"
  logdir="${logdirbase}/${this_script}"
  if [ ! -d "${logdir}" ]
  then
    /bin/mkdir -p "${logdir}" 2>/dev/null || exit 100
  fi
  logfile="${logdir}/${this_script}.log"
  if [ ! -f "${logfile}" ]
  then
    /bin/touch "${logfile}" || exit 110
  fi
  #
  mail_subject="${this_host} generated an event at ${this_time}"
  mail_recipients="you@domain.com"
}

function func_systemctl_check() {
  /bin/systemctl 2>/dev/null 1>&2; echo $?
}

function func_service_check() {
  if [ $(func_systemctl_check) -eq 0 ]
  then
    /bin/systemctl list-unit-files | grep enabled | grep -Ev "${exclude}" | awk '{print $1}' | while read i
    do
      s="$(/bin/systemctl status ${i} 2>/dev/null | grep -oP "(?<=Active: )[a-z]{1,}(?= )")"
      if [ ! -z "${s}" ]
      then
        echo -e "${i}\t${s}"
      fi
    done | column -t | sort -k2r
  fi
}

function func_service_dead() {
  if [ $(func_systemctl_check) -eq 0 ]
  then
    func_service_check | grep inactive | awk '{print $1}'
  fi
}

function func_service_restart() {
  if [ $(func_systemctl_check) -eq 0 ]
  then
    j=0; echo "${j}" > "${tmpfile}"
    func_service_dead | while read i
    do
      (( j = j + 2 )); echo "${j}" > "${tmpfile}"
      echo "Restarting dead ${i}" | tee -a "${logfile}"
      /bin/systemctl restart "${i}" 2>/dev/null
      sleep 3
      s="$(/bin/systemctl status ${i} 2>/dev/null | grep -oP "(?<=Active: )[a-z]{1,}(?= )")"
      echo "New status of ${i} is: ${s}" | tee -a "${logfile}"
    done
    j="$(head -1 "${tmpfile}")"
    if [ ${j} -gt 0 ]
    then
      tail -${j} "${logfile}" | mailx -s "${mail_subject}" "${mail_recipients}"
    fi
  fi
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
func_configure
func_service_restart
