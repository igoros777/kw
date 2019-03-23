#!/bin/bash
if [ -z "${1}" ]
then
  exit 1
else
  procnames="${@}"
  s=0
fi

function func_ipget() {
  # Get a list of IPs accessed by the specified process
  # Exclude private networks
  for procname in ${procnames}
  do
    a+=($(/usr/sbin/lsof -i -n $(pidof "${procname}" | sed 's/[^ ]* */-p &/g') 2>/dev/null | grep EST | grep -oP "(?<=->)([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})(?=:)" | grep -vP "(^127\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)"))
  done
}

function func_ipdrop() {
  # Block outbound access to those IPs
  for i in $(printf '%s\n' ${a[@]} | sort -u)
  do
    if [ $(/bin/ps -ef | grep -cE "[t]cpkill.*${i}$") -eq 0 ]
    then
      nohup /usr/sbin/tcpkill -9 host ${i} </dev/null >/dev/null 2>&1 &
    fi

    if [ $(/sbin/iptables -S | grep -cE " ${i}/") -eq 0 ]
    then
      /sbin/iptables -A OUTPUT -d ${i} -j DROP
      (( s = s + 1 ))
    fi
  done
}

function func_iptables_save() {
  # Remove duplicate entries from iptables
  tmpfile=$(mktemp)
  /sbin/iptables-save | awk '/^COMMIT$/ { delete x; }; !x[$0]++' > ${tmpfile}
  /sbin/iptables -F
  /sbin/iptables-restore < ${tmpfile}
  /sbin/service iptables save
  /sbin/service iptables restart
  /bin/rm -f ${tmpfile}
}

# RUNTIME
func_ipget
func_ipdrop
if [ ${s} -gt 0 ]
then
  func_iptables_save
fi
