#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                krazyworks.com
#                                  2017-12-01
# ----------------------------------------------------------------------------
# Locate unused IPs on your local subnet and create VIPs on your primary NIC
# to occupy those IPs. Additionally, the script can use `honeyport` honeypot
# script to listen on specified ports on all interfaces.
# ----------------------------------------------------------------------------

configure() {
  d=/etc/sysconfig/network-scripts
  n=$(route | grep -m1 ^default | awk '{print $NF}')
  p=$(ifconfig | sed -rn 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | awk -F. '{print $NF}')
  PORTS="8081 8082 8083 8084 8085"
}

ifcfgmake() {
  for i in $(arp-scan --localnet --quiet --ignoredups | grep -oE "([0-9]{1,3}\.){3}([0-9]{1,3})" | \
  awk -F. '{print $NF}' | awk '$1!=p+1{print p+1"\n"$1-1}{p=$1}'); do
    /bin/cp -p ${d}/ifcfg-${n} ${d}/ifcfg-${n}:${i}
    sed -i -e "s/\.${p}$/\.${i}/g" -e "s/=${n}$/=${n}:${i}/g" ${d}/ifcfg-${n}:${i}
  done
}

allup() {
  find ${d} -type f -name "ifcfg-${n}:*" | awk -F- '{print $NF}' | \
  xargs -P$(grep -c processor /proc/cpuinfo) -I% /usr/sbin/ifup %
  /usr/sbin/ifconfig
}

alldown() {
  find ${d} -type f -name "ifcfg-${n}:*" | awk -F- '{print $NF}' | \
  xargs -P$(grep -c processor /proc/cpuinfo) -I% /usr/sbin/ifdown %
  /usr/sbin/ifconfig
}

ifcfgdestroy() {
  alldown
  /bin/rm ${d}/ifcfg-${n}:
}

githoney() {
  k=Honeyport
  cd ~ && git clone https://github.com/securitygeneration/${k}.git
  if [ -d ~/${k} ]; then
    chmod 755 ~/${k}/*.sh ~/${k}/*.py
    for l in port stats; do
      ln -s ~/${k}/honey${l}.sh /usr/sbin/honey${l}
    done
    sed -i "s/PORT=31337/if [ ! -z \"\${1}\" ]; then PORT=\"\${1}\"; else PORT=31337; fi/g" ~/${k}/honeyport.sh
  fi
}

honeystart() {
  for m in $(echo ${PORTS}); do
    cd /tmp && nohup honeyport ${m} </dev/null >/dev/null 2>&1 &
  done
}

honeystop() {
  pkill honeyport 2>/dev/null 2>&1 && sleep 3
  for m in $(echo ${PORTS}); do
    lsof -i tcp:${m} | awk 'NR!=1 {print $2}' | xargs kill 2>/dev/null 2>&1
  done
}

# RUNTIME

configure
ifcfgmake
# allup
# githoney
# honeystart
# honeystop
# alldown
# ifcfgdestroy
