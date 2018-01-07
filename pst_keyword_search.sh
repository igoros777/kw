#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                krazyworks.com
#                                  2017-12-01
# ----------------------------------------------------------------------------
# Convert *.pst mailbox files to text and scan for keywords
# ----------------------------------------------------------------------------
#
readpass() {
  # Read your GPG password
  echo -n "Password: "
  read -s p
  if [ -z "${p}" ]; then
    exit 1
  fi
}

configure() {
  # Install readpst, if not there already
  if [ ! -x /usr/bin/readpst ]; then
    yum -y install libpst.x86_64 || exit 1
  fi
  # Install the Silver Searcher, if not there already
  if [ ! -x /usr/bin/ag ]; then
    yum -y install the_sliver_searcher || exit 1
  fi
  # Install GPG, if not there already
  if [ ! -x /usr/bin/gpg ]; then
    yum -y install gpg || exit 1
  fi
  # Put your *.pst files in here
  indir="/downloads/input"
  # Put your keywords in here, one per line
  # and encrypt it like so:
  # gpg --batch --symmetric --passphrase "${p}" "${keyword_list}" 2>/dev/null
  # chmod 600 "${keyword_list}.gpg"
  # /bin/rm -f "${keyword_list}"
  keyword_list="/tmp/keywords.txt"
  if [ ! -r "${keyword_list}.gpg" ]; then
    exit 1
  fi
  # Just in case you forgot
  chmod 400 "${keyword_list}.gpg"
}

extractpst() {
  # Find and convert *.pst files to text
  find "${indir}" -maxdepth 1 -mindepth 1 -type f -name "*\.pst" | while read pst; do
    cd "${indir}" && readpst -j $(grep -c processor /proc/cpuinfo) -b -e "${pst}"
  done
}

extractkeywords() {
  # Read keyword list into an array
  IFS=$'\n'; a=($(gpg --batch --decrypt --passphrase "${p}" "${keyword_list}.gpg" 2>/dev/null)); unset IFS
  # Assign keywords to a variable
  s=$(for ((i = 0; i < ${#a[@]}; i++)) ; do echo -n "${a[$i]}|" ; done | sed 's/|$//g')
}

findkeywords() {
  c=()
  IFS=$'\n'; b=($(ag -c "${s}" "${pst_folder}" | awk -F: '{print $1}' | sort -u)); unset IFS
  echo "PST:  ${pst_folder}"
  echo "---------------------------------------"
  for ((i = 0; i < ${#b[@]}; i++)) ; do echo "${b[$i]}" ; done | while read line; do
    message_id="$(grep -oP -m1 "(?<=Message-ID: <).*(?=>$)" "${line}")"
    if [ "$(for ((i = 0; i < ${#c[@]}; i++)) ; do echo "${c[$i]}"; done | grep -c "${message_id}")" -eq 0 ]; then
cat << EOF
FILE: $(echo "${line}")
KEYS: $(grep -oP "${s}" "${line}" | sort -u | tr '\n' ', ' | sed -r 's/,$//g')
DATE: $(grep -P -m1 "^Date:" "${line}" | awk -F: '{$1=""; print $0}' | sed 's/^  //g')
FROM: $(grep -P -m1 "^From:" "${line}" | grep -Po '(?i)\b[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}\b' | sort -u | tr '\n' ', ' | sed -r 's/,$//g')
TO:   $(grep -P -m1 "^To:" "${line}" | grep -Po '(?i)\b[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}\b' | sort -u | tr '\n' ', ' | sed -r 's/,$//g')
SUBJ: $(grep -P -m1 "^Subject:" "${line}" | awk -F: '{$1=""; print $0}' | sed 's/^  //g')
EOF
      echo
      c+=("${message_id}")
    fi
  done
}

find_do() {
  # Search and parse
  SAVEIFS=$IFS
  IFS=$(echo -en "\n\b")
  for pst_folder in $(find "${indir}" -maxdepth 1 -mindepth 1 -type d); do
    findkeywords
  done
  IFS=$SAVEIFS
}

# RUNTIME
readpass
configure
extractpst
extractkeywords
find_do
