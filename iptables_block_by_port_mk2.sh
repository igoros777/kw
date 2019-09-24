#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2019-09-19
# ----------------------------------------------------------------------------
# Script description
# The script will identify this system's external (Internet) IP address and
# open network ports. The script will then analyze firewall log entries for
# access records to this IP address and ports. If the number of succesfull
# connections from any single source exceeds the set threshold, the script
# will block the source IP via local firewall. An exception will be made
# for any IPs listed in /etc/hosts.allow and for private networks.
#
# Documentation URL: https://
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-09-19  igor  wrote this script
# ----------------------------------------------------------------------------

function func_configure() {
  # Just some basic config stuff
  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
  this_script_full="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  this_host=$(hostname | awk -F'.' '{print $1}')
  this_time=$(date +'%Y-%m-%d %H:%M:%S')
  mail_to="igor@comradegeneral.com"
  mail_from="igor@comradegeneral.com"
  mail_subject="Alert from ${this_host}:${this_script_full} at ${this_time}"

  # When blacklisting IPs, a comment will be added to the iptables rule. The comment will
  # consist of an epoch timestamp set ${jailtime} days in the future. This gives you an
  # opportunity to blacklist IPs temporarily. If you don't require this feature, set this
  # variable to 0
  jailtime=5

  # Either specify the target IP or have it set to your external Internet IP. This may
  # be useful if you don't have a static IP.
  target_ips="72.92.62.32"
  #target_ips="$(wget http://ipecho.net/plain -O - -q ; echo)"

  # Specify target ports or have them set dynamically by running nmap against your
  # primary IP set in the previous step.
  target_ports="21|53|80|135|443|44543|48090"
  #target_ports="$(nmap $target_ips 2>/dev/null | grep -oP "(?<=^)[0-9]{1,5}(?=\/)" | xargs | sed 's/ /|/g')"

  # The threshold in this case is entirely arbitrary. You'd have to set it according to how
  # popular your server is and what you would consider 'too many' hits.
  threshold=100

  # This is the log file that contains your firewall records. You can specify multiple log files
  # by providing absolute paths separated with spaces. You can also use asterisk at the end of
  # the filename to include any rotated/compressed logs (i.e. /var/log/messages* will include
  # /var/log/messages.0, /var/log/messages.1.gz, etc
  logfiles="/var/log/messages"

  # Target IP and at least one target port is required. If none were specified and none
  # could be determined automatically, the script cannot continue.
  if [ -z "${target_ips}" ] || [ -z "${target_ports}" ]
  then
   exit 1
 else
   # Just to let you know which logs and for what records the script is checking
   echo "Checking access records for ${target_ips}:${target_ports} in ${logfiles}"
  fi

  tmpfile=$(mktemp)
  i=0; echo "${i}" > ${tmpfile}

  tmpfile3=$(mktemp)
  k=0; echo "${k}" > ${tmpfile3}

  # Add to whitelist whatever IPs you have listed in /etc/hosts.allow
  whitelist="$(grep -oE "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})" /etc/hosts.allow 2>/dev/null | \
  sort -V | uniq | xargs | sed 's/ /|/g')"
  if [ -z "${whitelist}" ]
  then
    # If your /etc/hosts.allow is empty or doesn't exist, then at least whitelist
    # the local primary IP and your external Internet IP
    whitelist="$(/sbin/ifconfig | sed -rn 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | head -1)|$(wget http://ipecho.net/plain -O - -q ;echo)"
  fi

  # Here you can enter names of organizations (or whatever other strings) that may appear
  # in the output of the geoiplookup command. This allows you to whitelist IPs belonging
  # to a particular organization or geographic location
  org_whitelist="Delaware, Wilmington|Google"
}

function func_log_scan() {
  # The first line below you may need to adjust to matche specific format of your firewall log
  # The second line greps for the source IP address. You may need to make some changes here as well
  # The third line exclude private subnets (your local company or home networks)
  # The fourth line excludes any IP that is whitelisted
  # The fifth line extracts unique IPs, counts the number of hits, and selects those that exceeded the threshold
  for src_ip in $(zgrep -hE "dst=\"(${target_ips}):(${target_ports})\"" ${logfiles} 2>/dev/null | grep -v "DROP" |\
  grep -oP "(?<=src=\")([0-9]{1,3}\.){3}([0-9]{1,3})(?=:[0-9])" | \
  grep -vE "(^0\.)|(^127\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)" | \
  grep -vE "${whitelist}" | \
  sort -V | uniq -c | sort -k1rn | awk -v t=$threshold '{if($1>t)print$2}')
  do
    # Check if the selected IP may already be in your iptables either explicitly,
    # or as part of a subnet
    if [ $(/sbin/iptables -S | grepcidr -c "${src_ip}/32") -eq 0 ]
    then
      # Try to get owner/location information for the IP address
      src_info="$(geoiplookup ${src_ip} 2>/dev/null | grep -v 'not found' | awk -F: '{$1=""; print $0}' | sed 's/\//_/g' | xargs 2>/dev/null)"
      if [ -z "${src_info}" ]
      then
        src_info="unknown source"
      fi
      # Check the org_whitelist and block the IP and add a record to the system log.
      # These entries can be used to revert any unintended blocks.
      if [ $(echo "${src_info}" | grep -cE "${org_whitelist}") -eq 0 ]
      then
        echo "Blocking ${src_ip} after more than ${threshold} hits on ${target_ips}:${target_ports} from ${src_info}" | logger -t "${this_script}"
        if [ ${jailtime} -gt 0 ]
        then
          /sbin/iptables -A INPUT -m comment --comment "$(date -d"now + ${jailtime} days" +'%s')" -s "${src_ip}" -j DROP
        else
          /sbin/iptables -A INPUT -s "${src_ip}" -j DROP
        fi
        (( i = i + 1 ))
        echo "${i}" > ${tmpfile}
      fi
    fi
  done
}

function func_unblock() {
  if [ ${jailtime} -gt 0 ]
  then
    /sbin/iptables -S | grep -E 'comment.*"[0-9]{10,}"' | while read l
    do
     if [ $(echo ${l} | grep -oE '[0-9]{10,}') -lt $(date +'%s') ]
     then
       echo "${this_script} is dropping expired firewall block: ${l}"
       j="$(echo ${l} | sed 's/\-A/\-D/g')"
       /sbin/iptables $(eval echo $j)
       (( k = k + 1 ))
       echo "${k}" > ${tmpfile3}
     fi
    done
  fi
}

function func_iptables_save() {
  # If iptables configuration was modified, removes any duplicates and save it.
  # After saving, reload iptables service and send an email to the administrator.
  if [ $(cat ${tmpfile}) -gt 0 ] || [ $(cat ${tmpfile3}) -gt 0 ]
  then
    tmpfile2=$(mktemp)
    /sbin/service iptables save 2>/dev/null 1>$2
    /sbin/iptables-save | awk '/^COMMIT$/ { delete x; }; !x[$0]++' > ${tmpfile2}
    /sbin/iptables -F
    /sbin/iptables-restore < ${tmpfile2}
    /sbin/service iptables save
    /sbin/service iptables reload

    grep "${this_script}" /var/log/messages | tail -$(cat ${tmpfile}) |\
    mailx -r "${mail_from}" -s "${mail_subject}" "${mail_to}"
  fi
}

function func_cleanup() {
  # Clean up any lingering temp files
  /bin/rm -f ${tmpfile} ${tmpfile2} ${tmpfile3} 2>/dev/null
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
func_configure
func_log_scan
func_unblock
func_iptables_save
func_cleanup
