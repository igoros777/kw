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
  echo -n "Name the new sshd instance: "
  read instance_name
  echo -n "Specify the port for sshd-${instance_name}: "
  read instance_port
  confile="${confdir}/sshd_config-${instance_name}"
  initdfile="/etc/rc.d/init.d/sshd-${instance_name}"
}

function func_validate() {
  re='^[0-9]+$'
  if [ -z "${instance_name}" ] || [ -z "${instance_port}" ]
  then
    echo "Invalid instance name or port: ${instance_name:-null}; ${instance_port:-null}. Exiting..."
    exit 1
  fi

  if ! [[ "${instance_port}" =~ ^[0-9]+$ ]]
  then
    echo "Invalid port: ${instance_port}. Exiting..."
    exit 1
  fi

  if [ ${instance_port} -lt 1 ] || [ ${instance_port} -gt 65535 ]
  then
    echo "Invalid port: ${instance_name}. Exiting..."
    exit 1
  fi

  if [ $(lsof -i :${instance_port} | wc -l) -gt 0 ]
  then
    echo "Port ${instance_port} is already in use. Exiting..."
    exit 1
  fi

  if [ -f "${confile}" ]
  then
    echo "Configuration file ${confile} already exists. Exiting..."
    exit 1
  fi
}

function func_config_do() {
  /bin/cp -p "${confdir}/sshd_config" "${confile}"
  sed -i "s@^#Port 22@Port ${instance_port}@g" "${confile}"
  sed -i "s@^#PidFile /var/run/sshd.pid@PidFile /var/run/sshd-${instance_name}.pid@g" "${confile}"
  ln -s /usr/sbin/sshd /usr/sbin/sshd-${instance_name}
  /bin/cp /etc/rc.d/init.d/sshd /etc/rc.d/init.d/sshd-${instance_name}
  sed -i "s@^# config: /etc/ssh/sshd_config@# config: /etc/ssh/sshd_config-${instance_name}@g" "${initdfile}"
  sed -i "s@^# pidfile: /var/run/sshd.pid@# pidfile: /var/run/sshd-${instance_name}.pid@g" "${initdfile}"
  sed -i "s@\[ -f /etc/sysconfig/sshd \] \&\& \. /etc/sysconfig/sshd@\[ -f /etc/sysconfig/sshd-${instance_name} \] \&\& . /etc/sysconfig/sshd-${instance_name}@g" "${initdfile}"
  sed -i "s@^prog=\"sshd\"@prog=\"sshd-${instance_name}\"@g" "${initdfile}"
  sed -i "s@^SSHD=/usr/sbin/sshd@SSHD=/usr/sbin/sshd-${instance_name}@g" "${initdfile}"
  sed -i "s@^PID_FILE=/var/run/sshd.pid@PID_FILE=/var/run/sshd-${instance_name}.pid@g" "${initdfile}"
  sed -i "s@\[ -f /etc/ssh/sshd_config \]@\[ -f /etc/ssh/sshd_config-${instance_name} \]@g" "${initdfile}"
  echo "OPTIONS=\"-f /etc/ssh/sshd_config-${instance_name}\"" > "/etc/sysconfig/sshd-${instance_name}"
  /bin/cp -p /etc/pam.d/sshd /etc/pam.d/sshd-${instance_name} 2>/dev/null
}

function func_iptables_add() {
  if [ $(/sbin/iptables -S | grep -Ec  "^-A INPUT.*(ACCEPT|DROP)") -gt 0 ]
  then
    /sbin/iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${instance_port} -j ACCEPT
    /sbin/service iptables save
  fi
}

function func_enable() {
  /sbin/chkconfig --add sshd-${instance_name}
  /sbin/service sshd restart
  /sbin/service sshd-${instance_name} start
  if [ $(lsof -i :${instance_port} | wc -l) -eq 0 ]
  then
    echo "Something didn't work. Exiting..."
    exit 1
  else
    echo "sshd-${instance_name} is active:"
    lsof -i :${instance_port}
  fi
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
func_config_do
func_iptables_add
func_enable
