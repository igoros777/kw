#!/bin/bash
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2018-01-16
#
# ---------------------------------------------------
# Obtain a remote sites SSL fingerprint via localhost
# and compare it to the fingerprintes received via
# remote proxies. This can be useful for identifying
# potential SSL sniffing via certificate injection.
# ---------------------------------------------------
domains="${@}"
if [ -z "${domains}" ]; then echo "Specify domains"; exit 1; fi
rproxies="192.168.122.12 192.168.122.13"
leip="$(curl -s0 -k -q ifconfig.me 2>/dev/null)"
echo "${HOSTNAME} external IP: ${leip}"
for d in ${domains}; do
  for rproxy in ${rproxies}; do
    lsha="$(openssl s_client -connect ${d}:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha1 -noout -in /dev/stdin | awk -F= '{print $NF}')"
    rsha="$(ssh -qt ${rproxy} "openssl s_client -connect ${d}:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha1 -noout -in /dev/stdin" 2>/dev/null | awk -F= '{print $NF}')"
    if [ "$(echo "$lsha" | tr -dc '[:print:]' | od -c)" != "$(echo "$rsha" | tr -dc '[:print:]' | od -c)" ]; then
      reip="$(ssh -qt ${rproxy} 'curl -s0 -k -q ifconfig.me 2>/dev/null')"
      echo "Proxy's external IP: ${reip}"
      colordiff <(echo "$lsha" | tr -dc '[:print:]' | od -c) <(echo "$rsha" | tr -dc '[:print:]' | od -c)
    else
      echo "${d} checks out via ${rproxy}"
    fi
  done
done
