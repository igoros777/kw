#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                 2019-08-22
# ----------------------------------------------------------------------------
# A small helper script to rip CD-ROM to ISO and put it on NFS share
#
# CHANGE CONTROL
# ----------------------------------------------------------------------------
# 2019-08-22  igor  wrote this script
# ----------------------------------------------------------------------------
function func_configure() {
  nas="192.168.122.132"
  nfs_share="software"
  nfs_mount="/mnt/${nas}/${nfs_share}"
  d="/dev/cdrom"
  t="/mnt/cdrom"
  mkdir -p "${t}" "${nfs_mount}" 2>/dev/null
}

function func_mount_nfs() {
  if [ $(mountpoint ${nfs_mount} 2>/dev/null 1>&2; echo $?) -ne 0 ]; then
  mount.nfs ${nas}:${nfs_share} "${nfs_mount}" || exit 1
  fi
}

function func_mount_cdrom() {
  if [ $(mountpoint /mnt/cdrom 2>/dev/null 1>&2; echo $?) -ne 0 ]; then
  mount /dev/cdrom /mnt/cdrom || exit 2
  fi
}

function func_get_geometry() {
  bs=$(isoinfo -d -i /dev/cdrom | grep -i -E -m1 'block size' | grep -oP '[0-9]{1,}')
  cn=$(isoinfo -d -i /dev/cdrom | grep -i -E -m1 'volume size' | grep -oP '[0-9]{1,}')
  if [ -z "${bs}" ] || [ -z "${cn}" ]; then exit 3; fi
}

function func_cdrip() {
  dd if=/dev/cdrom of=${nfs_mount}/cdrom_${RANDOM}_$(date +'%Y-%m-%d_%H%M%S').iso \
  bs=${bs} count=${cn} status=progress
  umount /mnt/cdrom && eject /dev/cdrom
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
func_configure
func_mount_nfs
func_mount_cdrom
func_get_geometry
func_cdrip
