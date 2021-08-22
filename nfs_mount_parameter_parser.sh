#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                           igor@comradegeneral.com
#                                 2021-08-22
# ----------------------------------------------------------------------------
# Parse common mount options for NFS mounts in /proc/mount
# ----------------------------------------------------------------------------
# Change Log:
# ****************************************************************************
# 2021-08-22	igor	Wrote this script
# ****************************************************************************
#VAR,this_host,unknown
#VAR,hostid,unknown
#VAR,kernel,unknown
#VAR,this_time_db,unknown
#VAR,acdirmax,60
#VAR,acdirmin,30
#VAR,acregmax,60
#VAR,actimeo,unset
#VAR,addr,127.0.0.1
#VAR,clientaddr,127.0.0.1
#VAR,cto,cto
#VAR,diratime,diratime
#VAR,fg_bg,fg
#VAR,fileshare,unknown
#VAR,fsc,nofsc
#VAR,grpid,unset
#VAR,hard_soft,hard
#VAR,intr,intr
#VAR,local_lock,none
#VAR,nolock,lock
#VAR,lookupcache,all
#VAR,migration,nomigration
#VAR,minorversion,0
#VAR,mountaddr,127.0.0.1
#VAR,mountpoint,unknown
#VAR,mountport,0
#VAR,mountproto,unknown
#VAR,mountvers,unknown
#VAR,namlen,255
#VAR,nconnect,1
#VAR,nfs_client,unknown
#VAR,nfs_server,unknown
#VAR,noac,unset
#VAR,proto,unknown
#VAR,rdirplus,rdirplus
#VAR,relatime,relatime
#VAR,resvport,resvport
#VAR,retrans,unknown
#VAR,rsize,unknown
#VAR,rw_ro,unknown
#VAR,sec,unknown
#VAR,sharecache,sharecache
#VAR,softreval,nosoftreval
#VAR,strictatime,strictatime
#VAR,timeo,600
#VAR,version,unknown
#VAR,wsize,unknown

configure() {
  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
  this_script_full="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  this_host=$(hostname | awk -F'.' '{print $1}')
  this_time_db=$(date +'%Y-%m-%d %H:%M:%S')
  this_time=$(date -d "${this_time_db}" +'%Y-%m-%d_%H%M%S')
  outdir="/var/tmp/${this_script}"
  if [ ! -d "${outdir}" ]; then mkdir -p "${outdir}"; fi
  outfile="${outdir}/${this_script}_${this_time}.csv"
  IFS=$'\n'
  unset array_variables array_defaults
  array_variables=($(grep '^#VAR' "${this_script_full}" | awk -F, '{print $2}'))
  array_defaults=($(grep '^#VAR' "${this_script_full}" | awk -F, '{print $3}'))
  unset IFS
  for i in $(printf '$%s\n' ${array_variables[@]}); do echo -n "$(sed 's/^\$//g' <<<${i}),"; done | sed 's/,$/\n/g' > "${outfile}"
}

parse() {
  grep nfs.*mountport= /proc/mounts | while read line
  do
    for i in $(printf '$%s\n' ${array_variables[@]}); do eval unset $(sed 's/^\$//g' <<<${i}); done

    this_host="$(hostname | awk -F'.' '{print $1}')"
    hostid="$(hostid)"
    kernel="$(uname -r)"
    this_time_db="$(date +'%Y-%m-%d %H:%M:%S')"
    acdirmax="$(grep -oP "(?<=(,| )acdirmax=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    acdirmin="$(grep -oP "(?<=(,| )acdirmin=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    acregmax="$(grep -oP "(?<=(,| )acregmax=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    actimeo="$(grep -oP "(?<=(,| )actimeo=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    addr="$(grep -oP "(?<=(,| )addr=)(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)|(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(?=(,| ))" <<<"${line}")"
    clientaddr="$(grep -oP "(?<=(,| )clientaddr=)(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)|(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(?=(,| ))" <<<"${line}")"
    cto="$(grep -oP "(?<=(,| ))(no)?cto(?=(,| ))" <<<"${line}")"
    diratime="$(grep -oP "(?<=(,| ))(no)?diratime(?=(,| ))" <<<"${line}")"
    fg_bg="$(grep -oP "(?<=(,| ))(f|b)g(?=(,| ))" <<<"${line}")"
    fileshare="$(awk -F: '{print $2}' <<<"${line}" | awk '{print $1}' | sed -r 's/(\\)?040/ /g')"
    fsc="$(grep -oP "(?<=(,| ))(no)?fsc(?=(,| ))" <<<"${line}")"
    grpid="$(grep -oP "(?<=(,| ))grpid(?=(,| ))" <<<"${line}")"
    hard_soft="$(grep -oP "(?<=(,| ))(hard|soft)(?=(,| ))" <<<"${line}")"
    intr="$(grep -oP "(?<=(,| ))(no)?intr(?=(,| ))" <<<"${line}")"
    local_lock="$(grep -oP "(?<=(,| )local_lock=)[[:alnum:]]{1,}(?=(,| ))" <<<"${line}")"
    nolock="$(grep -oP "(?<=(,| ))(no)?lock(?=(,| ))" <<<"${line}")"
    lookupcache="$(grep -oP "(?<=(,| )lookupcache=)[[:alnum:]]{1,}(?=(,| ))" <<<"${line}")"
    migration="$(grep -oP "(?<=(,| ))(no)?migration(?=(,| ))" <<<"${line}")"
    minorversion="$(grep -oP "(?<=(,| )minorversion=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    mountaddr="$(grep -oP "(?<=(,| )mountaddr=)(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)|(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(?=(,| ))" <<<"${line}")"
    mountpoint="$(awk '{print $2}' <<<"${line}" | sed -r 's/(\\)?040/ /g')"
    mountport="$(grep -oP "(?<=(,| )mountport\=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    mountproto="$(grep -oP "(?<=(,| )mountproto\=)[[:alnum:]]{1,}(?=(,| ))" <<<"${line}")"
    mountvers="$(grep -oP "(?<=(,| )mountvers\=)[[:alnum:]]{1,}(?=(,| ))" <<<"${line}")"
    namlen="$(grep -oP "(?<=(,| )namlen=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    nconnect="$(grep -oP "(?<=(,| )nconnect=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    nfs_client="$(ifconfig | sed -rn 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')"
    nfs_server="$(awk -F: '{print $1}' <<<"${line}")"
    noac="$(grep -oP "(?<=(,| ))noac(?=(,| ))" <<<"${line}")"
    proto="$(grep -oP "(?<=(,| )proto\=)[[:alnum:]]{1,}(?=(,| ))" <<<"${line}")"
    rdirplus="$(grep -oP "(?<=(,| ))(no)?rdirplus(?=(,| ))" <<<"${line}")"
    relatime="$(grep -oP "(?<=(,| ))(no)?relatime(?=(,| ))" <<<"${line}")"
    resvport="$(grep -oP "(?<=(,| ))(no)?resvport(?=(,| ))" <<<"${line}")"
    retrans="$(grep -oP "(?<=(,| )retrans=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    rsize="$(grep -oP "(?<=(,| )rsize=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    rw_ro="$(grep -oP "(?<=(,| ))r(w|o)(?=(,| ))" <<<"${line}")"
    sec="$(grep -oP "(?<=(,| )sec=)[[:alnum:]]{1,}(?=(,| ))" <<<"${line}")"
    sharecache="$(grep -oP "(?<=(,| ))(no)?sharecache(?=(,| ))" <<<"${line}")"
    softreval="$(grep -oP "(?<=(,| ))(no)?softreval(?=(,| ))" <<<"${line}")"
    strictatime="$(grep -oP "(?<=(,| ))(no)?strictatime(?=(,| ))" <<<"${line}")"
    timeo="$(grep -oP "(?<=(,| )timeo=)[0-9]{1,}(?=(,| ))" <<<"${line}")"
    version="$(grep -oP "(?<=(,| )vers\=)[[:alnum:]]{1,}(?=(,| ))" <<<"${line}")"
    wsize="$(grep -oP "(?<=(,| )wsize=)[0-9]{1,}(?=(,| ))" <<<"${line}")"

    for ((i = 0; i < ${#array_variables[@]}; i++))
    do
      if [ -z "$(eval echo $(echo $`eval echo "${array_variables[$i]}"`))" ]
      then
        eval "$(echo "${array_variables[$i]}")"="$(echo "\"${array_defaults[$i]}\"")"
      fi
    done

    for i in $(printf '$%s\n' ${array_variables[@]}); do eval echo -n "${i},"; done | sed 's/,$/\n/g' >> "${outfile}"
  done
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
configure
parse
if [ -f "${outfile}" ]; then
  echo -e "Output saved to ${outfile}\n"
  cat "${outfile}"
fi
