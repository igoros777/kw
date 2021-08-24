#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                           igor@comradegeneral.com
#                                 2021-08-23
# ----------------------------------------------------------------------------
# A wrapper script for the nfsiostat command that will generate timestamped
# CSV output.
# Prerequisites: timeout, dos2unix, unbuffer, nfsiostat
# ----------------------------------------------------------------------------
# Change Log:
# ****************************************************************************
# 2021-08-23	igor	Wrote this script
# ****************************************************************************
interval="${1}"
count="${2}"
fs="${3}"

configure() {
  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
  this_script_full="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  this_host=$(hostname | awk -F'.' '{print $1}')
  this_time_db=$(date +'%Y-%m-%d %H:%M:%S')
  this_time=$(date -d "${this_time_db}" +'%Y-%m-%d_%H%M%S')
  outdir="/var/tmp/nfsiostat"
  mkdir -p "${outdir}"
  outfile="${outdir}/nfsiostat_${this_host}_${this_time}.csv"
  tmpfile=$(mktemp)
  if [ -z "${interval}" ] || [ -z "${count}" ] || [ -z "${fs}" ]; then exit 21; fi
  NFSIOSTAT=$(which nfsiostat 2>/dev/null) || exit 23
  TIMEOUT=$(which timeout 2>/dev/null) || exit 25
  UNBUFFER=$(which unbuffer 2>/dev/null) || exit 25
  DOS2UNIX=$(which dos2unix 2>/dev/null) || exit 27
}

do_nfsiostat() {
  (( timer = ( interval * count ) + 1 ))
  ${TIMEOUT} ${timer} ${NFSIOSTAT} 2 2>/dev/null | ${UNBUFFER} -p grep --line-buffer -v o | \
  ${UNBUFFER} -p ts '%Y-%m-%d_%H:%M:%S' | grep --line-buffer '\.' >> "${outfile}"
  ${DOS2UNIX} "${outfile}"
  sed -i 'N;N;s/\n/ /g' "${outfile}"
  cat "${outfile}" | while read line; do
    t="$(echo "${line}" | awk '{print $1}')"
    sed -i "s/${t}//2g" "${outfile}"
  done
  sed -ri 's/\s{1,}/,/g' "${outfile}"
  sed -i 's/_/ /g' "${outfile}"
  tail -n +2 "${outfile}" > "${tmpfile}"
  cat "${tmpfile}" | (echo "timestamp,op_s,rpc_bklog,r_ops_s,r_kB_s,r_kB_op,r_retrans,r_retrans_pct,r_avg_RTT_ms,r_avg_exe_ms,w_ops_s,w_kB_s,w_kB_op,w_retrans,w_retrans_pct,w_avg_RTT_ms,w_avg_exe_ms" && cat) > "${outfile}"
  echo "${outfile}"
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
configure
do_nfsiostat
