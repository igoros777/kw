#!/bin/bash
#
# Identified IPs blocked by TCP Wrappers (/etc/hosts.deny) multiple times
# and permanently block those IPs with IPTables firewall
#
m="denied access to "
t=10
whitelist="192.168.122.|192.168.123."
zgrep "${m}" /var/log/messages* | \
for ip in `grep -oE "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})" | grep -Ev "${whitelist}" | \
sort -u -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n`
do
	n=$(zgrep -c "\b${ip} ${m}\b" /var/log/messages* | awk -F':' '{sum=sum+$NF} END {print sum}')
	if [ ${n} -ge ${t} ]
	then
		if [ `/sbin/iptables -S | grep -c "${ip}.*DROP"` -eq 0 ]
		then
			c=$(geoiplookup ${ip} | grep Country | grep -woE [A-Z]{2}, | sed 's/,//g')
			echo -e "Banning ${ip} from ${c} after ${n} TCP Wrappers denials" | tee >(logger)
			/sbin/iptables -A INPUT -s ${ip} -j DROP
		fi
	fi
done
/sbin/service iptables save
