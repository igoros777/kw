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
# Generate secondary SSHd service on RHEL/CentOS 7
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-04-03  igor  wrote this script
# ----------------------------------------------------------------------------

function func_configure() {
  confdir="/etc/ssh"
  echo -n "Name the new sshd instance: "
  read instance_name
  echo -n "Specify the port for sshd-${instance_name}: "
  read instance_port
  confile="${confdir}/sshd_config-${instance_name}"
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
  sed -i "/# BEGIN ANSIBLE MANAGED BLOCK/,/# END ANSIBLE MANAGED BLOCK/d" "${confile}"
  ln -s /usr/sbin/sshd /usr/sbin/sshd-${instance_name}
  /bin/cp /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd-${instance_name}.service
  sed -i "s@Description=OpenSSH server daemon@Description=OpenSSH server daemon ${instance_name}@g" /usr/lib/systemd/system/sshd-${instance_name}.service
  sed -i "s@ExecStart=/usr/sbin/sshd -D \$OPTIONS@ExecStart=/usr/sbin/sshd-${instance_name} -f ${confile} -D \$OPTIONS@g" /usr/lib/systemd/system/sshd-${instance_name}.service
  /bin/cp -p /etc/pam.d/sshd /etc/pam.d/sshd-${instance_name} 2>/dev/null
}

function func_iptables_add() {
  if [ $(/sbin/iptables -S | grep -Ec  "^-A INPUT.*(ACCEPT|DROP)") -gt 0 ]
  then
    /sbin/iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${instance_port} -j ACCEPT
    /sbin/iptables-save
  fi
}

function func_enable() {
  systemctl daemon-reload
  systemctl enable sshd-${instance_name} --now 2>/dev/null
  systemctl start sshd-${instance_name} 2>/dev/null
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
