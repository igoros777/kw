#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2019-12-14
# ----------------------------------------------------------------------------
# Script description
# Documentation URL: https://
# Validate a list of HTTPS proxies and generate Squid peer configuration
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-12-14  igor  wrote this script
# ----------------------------------------------------------------------------


configure() {
  basedir="/var/adm/bin/squid"
  infile="${basedir}/proxyips.txt"
  squiddir="/etc/squid"
  squidpeers="${squiddir}/peers.conf"
  creds="user:pass"
  proto="https"
  testurl="${proto}://ipecho.net/plain"
  maxthreads=200
  timeout_01=5
  # realip="your actual external IP"
  realip="$(curl -q -s0 -k "${testurl}")"
  if [ -z "${realip}" ]
  then
    echo "Unable to determine your actual external IP. Exiting..."
    exit 1
  fi
}

backup_do() {
  /bin/mv "${squidpeers}" "${squidpeers}_$(date +'%Y-%m-%d')" 2>/dev/null
}

proxy_check() {
  my_ip="$(/usr/bin/timeout ${timeout_01} /usr/bin/curl --silent --proxy "${line}" --proxy-user "${creds}" "${testurl}" | grep -oE -m1 "([0-9]{1,3}\.){3}([0-9]{1,3})")"
  if [ ! -z "${my_ip}" ] && [ $(echo "${my_ip}" | fgrep -c "${realip}") -eq 0 ] && [ $(echo "${my_ip}" | grep -coE "([0-9]{1,3}\.){3}([0-9]{1,3})") -eq 1 ]
  then
    echo "${line}"
    ip=$(echo ${line} | awk -F: '{print $1}')
    port=$(echo ${line} | awk -F: '{print $2}')
    echo "cache_peer ${ip} parent ${port} 0 proxy-only round-robin login=${creds}" >> "${squidpeers}"
    echo "cache_peer_access ${ip} allow all" >> "${squidpeers}"
  fi
}

export -f proxy_check

# RUNTIME
configure
backup_do

i=1
cat "${infile}" | sort -Vu | shuf | while read line
do
  if [ ${i} -le ${maxthreads} ]
  then
    proxy_check &
    (( i = i + 1 ))
  else
    i=1
    sleep ${timeout_01}
  fi
done

sleep ${timeout_01}
/sbin/service squid reload
