#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2019-08-09
# ----------------------------------------------------------------------------
# Just a quick way of copying files/folders from any to any server using your
# automation service account. This acconut would need passwordless sudo
#
# Syntax:
# g <source_host>:/<path>/[filename] <target_host>:/<path>/
# if "<target_host>:/<path>/" does not exist, it will be created.
#
# Example:
# root@saltmaster# g dev-tomcat01:/etc/ntp/ prod-tomcat02:/etc/ntp_from_dev-tomcat01/
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-08-09  igor  wrote this script
# ----------------------------------------------------------------------------

rnd="${RANDOM}"
u="service_account"
rsa_id="$(find /home/${u}/.ssh -mindepth 1 -maxdepth 1 -type f -name "id*rsa" | head -1)"
if [ ! -r "${rsa_id}" ]; then exit 3; fi
ssh_opt="-qtT -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -i ${rsa_id}"
sshfs_opt="allow_other,IdentityFile=${rsa_id},UserKnownHostsFile=/dev/null,StrictHostKeyChecking=no"

if [ ! -z "${1}" ] && [ ! -z "${2}" ]
then
  s="${1}"
  s_host="$(awk -F':' '{print $1}' <<<"${s}")"
  s_node="$(awk -F':' '{for(i=2;i<=NF;++i)print $i}' <<<"${s}")"
  s_dir="$(awk -F'/' -v OFS='/' '{$NF=""; print $0}' <<<"${s_node}")"
  s_file="$(awk -F'/' '{print $NF}' <<<"${s_node}")"
  t="${2}"
  t_host="$(awk -F':' '{print $1}' <<<"${t}")"
  t_dir="$(awk -F':' '{for(i=2;i<=NF;++i)print $i}' <<<"${t}")"
else
  exit 1
fi

s_mnt="/mnt/source/${s_host}_${rnd}"
t_mnt="/mnt/target/${t_host}_${rnd}"
mkdir -p "${s_mnt}" "${t_mnt}"
/usr/bin/ssh ${ssh_opt} ${u}@${t_host} "sudo su - root -c 'mkdir -p \"${t_dir}\"'" 2>/dev/null 1>&2
sshfs -o ${sshfs_opt} ${u}@${s_host}:${s_dir} ${s_mnt} -o sftp_server="/usr/bin/sudo /usr/libexec/openssh/sftp-server"
sshfs -o ${sshfs_opt} ${u}@${t_host}:${t_dir} ${t_mnt} -o sftp_server="/usr/bin/sudo /usr/libexec/openssh/sftp-server"
if [ $(mountpoint "${s_mnt}" 2>/dev/null 1>&2; echo $?) -eq 0 ] && [ $(mountpoint "${t_mnt}" 2>/dev/null 1>&2; echo $?) -eq 0 ]
then
  if [ ! -z "${s_file}" ]
  then
    rsync -aqKx "${s_mnt}/${s_file}" "${t_mnt}"/
  else
    rsync -aqKx "${s_mnt}"/ "${t_mnt}"/
  fi
  umount -f ${s_mnt} ${t_mnt}
fi
/bin/rmdir "${s_mnt}" "${t_mnt}"
