#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2020-04-13
# ----------------------------------------------------------------------------
# Retrieve a server's memory utilization information via SNMP
# ----------------------------------------------------------------------------
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2020-04-13  igor  wrote this script

h="${1}"
if [ -z "${h}" ]
then
  echo "You need to supply this command with a valid hostname. Exiting..."
  exit 300
else
  ping_status=$(timeout 6 ping -c 2 -W 1 ${h} >/dev/null 2>&1 ; echo $?)
  if [ -z "${ping_status}" ] || [ ${ping_status} -ne 0 ]
  then
    echo "Unable to ping ${h}. Exiting..."
    exit 310
  fi
fi

configure() {
  total_ram='1.3.6.1.4.1.2021.4.5'
  total_ram_available='1.3.6.1.4.1.2021.4.6'
  total_ram_buffered='1.3.6.1.4.1.2021.4.14'
  total_cached_memory='1.3.6.1.4.1.2021.4.15'
  # Update the SNMP community string. Make sure the script has appropriate permissions
  s="*********************"

  RED='\033[1;31m'
  GREEN='\033[1;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m'

  hfqdn="$(nslookup $h 2>/dev/null | grep -m1 '^Name:' | awk '{print $NF}')"
  if [ -z "${hfqdn}" ]
  then
    hfqdn="${h}"
  fi
}

walk() {
  snmpwalk -v 2c -c $s $h $@
}

chomp() {
  awk -F: '{print $NF}' | grep -oP '[0-9]{1,}'
}

mem_check() {
  echo "-------------------------------------"
  echo "${hfqdn}"
  echo "-------------------------------------"
  echo -e "Total RAM installed:\t ~$(echo "scale=0;($(walk ${total_ram} | chomp))/1024/1024"|bc -l)GB"
  echo -e "Allocated memory:\t ~$(echo "scale=0;($(walk ${total_ram} | chomp)\
  -$(walk ${total_ram_available} | chomp))/1024/1024"|bc -l)GB"
  echo -e "Unallocated memory:\t ~$(echo "scale=0;($(walk ${total_ram_available} | chomp))/1024/1024"|bc -l)GB"

  echo -e "Utilized memory:\t ~$(echo "scale=0;($(walk ${total_ram} | chomp)\
  -$(walk ${total_cached_memory} | chomp)\
  -$(walk ${total_ram_buffered} | chomp))/1024/1024"|bc -l)GB ($(echo "scale=0;($(walk ${total_ram} | chomp)\
  -$(walk ${total_cached_memory} | chomp)\
  -$(walk ${total_ram_buffered} | chomp)) * 100 / $(walk ${total_ram} | chomp)"|bc -l)%)"

  available_pct="$(echo "scale=0;($(walk ${total_ram_available} | chomp)\
  +$(walk ${total_cached_memory} | chomp)\
  +$(walk ${total_ram_buffered} | chomp)) * 100 / $(walk ${total_ram} | chomp)"|bc -l)"

  if [ ${available_pct} -gt 40 ]
  then
    highlight="${GREEN}"
  elif [ ${available_pct} -le 40 ] && [ ${available_pct} -gt 15 ]
  then
    highlight="${YELLOW}"
  elif [ ${available_pct} -le 15 ]
  then
    highlight="${RED}"
  fi

  echo ""
  echo -e "${highlight}Available memory:\t ~$(echo "scale=0;($(walk ${total_ram_available} | chomp)\
  +$(walk ${total_cached_memory} | chomp)\
  +$(walk ${total_ram_buffered} | chomp))/1024/1024"|bc -l)GB ($(echo "scale=0;($(walk ${total_ram_available} | chomp)\
  +$(walk ${total_cached_memory} | chomp)\
  +$(walk ${total_ram_buffered} | chomp)) * 100 / $(walk ${total_ram} | chomp)"|bc -l)%)${NC}"

  echo ""
  echo "Available memory composition:"
  echo -e "\tCached:   \t ~$(echo "scale=0;($(walk ${total_cached_memory} | chomp))/1024/1024"|bc -l)GB"
  echo -e "\tBuffered:\t ~$(echo "scale=0;($(walk ${total_ram_buffered} | chomp))/1024/1024"|bc -l)GB"
  echo -e "\tUnallocated:\t ~$(echo "scale=0;($(walk ${total_ram_available} | chomp))/1024/1024"|bc -l)GB"
  echo "-------------------------------------"
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
configure
mem_check
