#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                              igor@comradegeneral.com
#                                 2019-03-25
# ----------------------------------------------------------------------------
# Generate secondary SSHd service on CentOS 5 & 6
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-03-25  igor  wrote this script
# ----------------------------------------------------------------------------

function func_configure() {
  confdir="/etc/ssh"
  echo -n "Name the sshd instance to delete: "
  read instance_name
  confile="${confdir}/sshd_config-${instance_name}"
  initdfile="/etc/rc.d/init.d/sshd-${instance_name}"
}

function func_validate() {
  re='^[0-9]+$'
  if [ -z "${instance_name}" ]
  then
    echo "Invalid port: ${instance_name:-null}. Exiting..."
    exit 1
  fi

  if [ ! -f "${confile}" ] || [ ! -f "${initdfile}" ]
  then
    echo "Instance sshd-${instance_name} not found. Exiting..."
    exit 1
  fi

  instance_port="$(grep -oP "(?<=^Port )[0-9]{1,5}(?=)" "${confile}")"

  if [ -z "${instance_port}" ]
  then
    echo "Unable to determine instance port. Exiting..."
    exit 1
  fi

  if ! [[ "${instance_port}" =~ ^[0-9]+$ ]]
  then
    echo "Invalid instance port: ${instance_port}. Exiting..."
    exit 1
  fi

  if [ ${instance_port} -lt 1 ] || [ ${instance_port} -gt 65535 ]
  then
    echo "Invalid instance port: ${instance_name}. Exiting..."
    exit 1
  fi
}

function func_iptables_del() {
  /sbin/iptables -S | grep "dport ${instance_port}" | sed 's/-A /-D /g' | while read i
  do
    /sbin/iptables ${i}
  done
  /sbin/service iptables save
}

function func_disable() {
  /sbin/chkconfig --del sshd-${instance_name}
  /sbin/service sshd-${instance_name} stop
  /sbin/service sshd restart
  if [ $(lsof -i :${instance_port} | wc -l) -gt 1 ]
  then
    echo "Something didn't work. Exiting..."
    exit 1
  else
    echo "sshd-${instance_name} is off"
  fi
}

function func_unconfig_do() {
  /bin/rm "${confile}" 2>/dev/null
  unlink /usr/sbin/sshd-${instance_name} 2>/dev/null
  /bin/rm /etc/rc.d/init.d/sshd-${instance_name} 2>/dev/null
  /bin/rm /etc/pam.d/sshd-${instance_name} 2>/dev/null
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
func_configure
func_validate
func_disable
func_iptables_del
func_unconfig_do
