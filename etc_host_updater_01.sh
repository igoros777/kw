#!/bin/bash
# Resolve domain IP and update /etc/hosts as needed. This can be useful if
# DNS lookup is slow and you have a process that keeps looking up the same
# domains over and over again. But, at the same time, you don't want to just
# replace the domain name with a static IP that may change at some point in the
# future. Ugh...

configure() {
  tt="$(date +'%Y-%m-%d_%H%M%S')"
  f="/etc/hosts"
  DIG="$(which dig 2>/dev/null | head -1)"
  declare -a ad=('domain1.com' 'domain2.com' 'domain3.com')
}

verify() {
  if [ ! -f "${f}" ] || [ ! -w "${f}" ]
  then
    echo "File ${f} cannot be opened for writing. Exiting..."
    exit 1
  fi

  if [ -z "${DIG}" ] || [ ! -x "${DIG}" ]
  then
    echo "Unable to find the 'dig' utility. Please install 'bind-utils'. Exiting..."
    exit 1
  fi
}

ip_check() {
  for fqdn in $(printf '%s\n' ${ad[@]})
  do
    ipo=$(grep -m1 -E "\b${fqdn}\b" "${f}" | awk '{print $1}' | grep -m1 -oE "([0-9]{1,3}\.){3}([0-9]{1,3})")
    ipn=$(grep -m1 -oE "([0-9]{1,3}\.){3}([0-9]{1,3})" <(${DIG} +short ${fqdn}))
    if [ -z "${ipo}" ] && [ ! -z "${ipn}" ]
    then
      /bin/cp -p "${f}" "${f}_${tt}"
      echo -e "${ipn}\t${fqdn}" >> "${f}"
    elif [ ! -z "${ipo}" ] && [ ! -z "${ipn}" ]
    then
      if [ "${ipo}" != "${ipn}" ]
      then
        /bin/cp -p "${f}" "${f}_${tt}"
        sed -i "s/${ipo}/${ipn}/g" "${f}"
      fi
    fi
  done
}

# RUNTIME
configure
verify
ip_check
