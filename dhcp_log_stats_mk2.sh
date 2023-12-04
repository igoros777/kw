#!/bin/bash

grep dhcpd /var/log/messages | grep -oE '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | sort -u | while read line
do
  iplist="$(grep ".*dhcpd.*${line}" /var/log/messages | grep -oE "([0-9]{1,3}\.){3}([0-9]{1,3})" | sort -u | xargs)"
  if [ -z "${iplist}" ]
  then
    iplist=none
  fi
  devname="$(grep ".*dhcpd.*${line}" /var/log/messages | grep -oP "(?<=\()[[:alnum:]]{1,}(?=\))" | sort -u | xargs)"
  if [ -z "${devname}" ]
  then
    devname=none
  fi
  status=OFF
  if [ $(for ipa in ${iplist}; do arp-scan -xq "${ipa}" 2>/dev/null | grep -c ${ipa}; done | wc -l) -gt 0 ]
  then
    status=ON
  fi
  sed 's/://g' <<<${line} | tr '[:lower:]' '[:upper:]' | cut -c 1-6 | while read mac
  do
    ouilist="$(grep ^${mac} /root/ieee-oui.txt | awk '{ $1=""; sub(/^[\t ]+/, ""); print }' | xargs)"
    if [ -z "${ouilist}" ]
    then
      ouilist=none
    fi
    echo -e "${line}^${status}^${iplist}^${devname}^${ouilist}"
  done
done | (echo "MAC^ONLINE^IP ADDRESS^HOSTNAME^MANUFACTURER" && cat) | column -s^ -t
