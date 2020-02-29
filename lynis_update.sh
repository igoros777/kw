#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                           igor@comradegeneral.com
#                                  2020-02-29
# ----------------------------------------------------------------------------
# Update current installation of Lynis. Only use this script if Lynis was
# installed via a tarball. If you have a version installed via RPM or another
# package managements tool, uninstall it first.
# ----------------------------------------------------------------------------

configure() {
  echo "Running script configuration"
  # Specify Lynis executable
  LYNIS=/usr/bin/lynis
  [ -x "${LYNIS}" ] || (echo "Lynis executable ${LYNIS} not found. Exiting..." && exit 1110)

  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")

  # Get update info
  echo "Getting update info"
  update_info="$(${LYNIS} update info)"
  [ -z "${update_info}" ] && (echo "Unable to get update info. Exiting..." && exit 1120)

  # Parse update info
  echo "Parsing update info"
  update_status="$(echo "${update_info}" | grep -E '^\s+Status' | awk '{print $NF}')"
  release_date="$(echo "${update_info}" | grep -E '^\s+Release' | awk '{print $NF}')"
  current_version="$(echo "${update_info}" | grep -E '^\s+Version' | awk '{print $NF}')"
  update_location="$(echo "${update_info}" | grep -E '^\s+Update location' | awk '{print $NF}' | sed 's/\/$//g')"
  update_host="$(echo "${update_location}" | grep -oP "(?<=:\/\/).*?(?=\/)")"

  ([ -z "${update_status}" ] || [ -z "${current_version}" ] || \
  [ -z "${release_date}" ] || [ -z "${update_location}" ] || [ -z "${update_host}" ]) && \
  (echo "Unable to parse update info. Exiting..." && exit 1130)

  # Resolve update host
  echo "Resolving update host"
  update_host_ip="$(dig +short "${update_host}" | \
  grep -m1 -oE "([0-9]{1,3}\.){3}([0-9]{1,3})")"
  [ -z "${update_host_ip}" ] && \
  (echo "Unable to resolve ${update_host}. Exiting..." && exit 1135)

  # Verify update host port access
  echo "Verifying update host port access"
  nc -v -i1 -w1 "${update_host_ip}" 443 2>/dev/null 1>&2 || \
  (echo "Unable to access ${update_host_ip}:443. Exiting..." && exit 1137)

  # Verify access to update URL
  echo "Verifying update location availability"
  if [ ! $(curl -s0SfkL "${update_location}" 2>/dev/null | \
           grep -oP "(?<=\<title\>).*?(?=\<\/title\>)" 2>/dev/null | \
           grep -c Lynis) -gt 0 ]
  then
    echo "Unable to reach ${update_location}. Exiting..."
    exit 1140
  fi

  # Determine download URL
  echo "Checking for download URL"
  base_url="$(awk -F'/' '{print $1"/"$2"/"$3}' <<<"${update_location}")"
  path_url="$(curl -s0SfkL "${update_location}" 2>/dev/null | awk 'BEGIN{
  RS="</a>"
  IGNORECASE=1
  }
  {
    for(o=1;o<=NF;o++){
      if ( $o ~ /href/){
        gsub(/.*href=\042/,"",$o)
        gsub(/\042.*/,"",$o)
        print $(o)
      }
    }
  }' | grep -m1 -iE "(lynis.*downloads)|(downloads.*lynis)")"
  [ -z "${path_url}" ] && (echo "Unable to determine download URL. Exiting..." && exit 1150)
  download_url="${base_url}/${path_url}"

  # Determine latest version download URL
  echo "Checking for the latest version download link"
  version_url="$(curl -s0SfkL "${download_url}" 2>/dev/null | awk 'BEGIN{
  RS="</a>"
  IGNORECASE=1
  }
  {
    for(o=1;o<=NF;o++){
      if ( $o ~ /href/){
        gsub(/.*href=\042/,"",$o)
        gsub(/\042.*/,"",$o)
        print $(o)
      }
    }
  }' | grep -m1 -iE "lynis.*\.(tar\.gz|tgz)")"
  [ -z "${version_url}" ] && (echo "Unable to determine latest version download link. Exiting..." && exit 1150)
  version_file="$(echo "${version_url}" | awk -F'/' '{print $NF}')"
}

lynis_update() {
  # Check if update is needed
  if [ "${update_status}" == "Outdated" ]
  then
    echo "Update is required."

    # Download the latest version
    echo "Downloading ${version_file}"
    curl -s0SfkL "${version_url}" > ~/"${version_file}"
    [ $(file --mime-type ~/"${version_file}" -F$'\t' | awk -F'\t *' '$2 ~/^application\/x-gzip/ { print $1 }') ] || \
    (echo "Unable to download ${version_url}. Exiting..." && exit 1160)

    # Uncompress the latest version
    echo "Uncompressing ~/${version_file}"
    [ -d ~/lynis ] && /bin/mv ~/lynis ~/lynis_$(date +'%Y-%m-%d_%H%M') 2>/dev/null
    cd ~ && tar xfz ~/"${version_file}" || (echo "Unable to uncompress ~/${version_file}. Exiting..." && exit 1170)
    [ -d /usr/local/lynis ] && cd /usr/local && tar cfz ~/lynis_previous_$(date +'%Y-%m-%d_%H%M').tar.gz lynis && \
    /bin/rm -rf lynis && cd ~
    /bin/mv -f ~/lynis /usr/local/ && ln -s /usr/local/lynis/lynis ${LYNIS} 2>/dev/null
    /bin/rm ~/"${version_file}" 2>/dev/null

    ${LYNIS} update info
    echo "Update complete"
  else
    echo "Update is not required at this time. Exiting"
    exit 0
  fi
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
configure
lynis_update
