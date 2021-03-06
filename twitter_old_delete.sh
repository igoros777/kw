#!/bin/bash
# Parse Twitter's 'tweet.js' data file and delete old posts that have no likes or retweets

if [ -z "${1}" ]; then
  echo "Specify the location of tweet.js"
  exit 1
else
  infile="${1}"
fi

if [ -z "${2}" ]; then
  echo "Specify the username without '@'"
  exit 1
else
  u="${2}"
fi

if [ ! -f "${infile}" ]; then
  echo "Input file ${infile} not found. Exiting..."
  exit 1
fi

#T="/usr/local/rvm/gems/ruby-2.2.4/bin/t"
T="/usr/local/bin/t"
if [ ! -x "${T}" ]; then
  echo "Unable to access ${T}"
  exit 1
fi

read -r ux <<<$(${T} accounts | sed 'N;s/\n/ /' | grep "${u}" | awk '{print $2}')
${T} set active ${u} ${ux}

f="$(mktemp)"
mt="$(date -d '3 months ago' +'%s')"

echo "Writing Tweet IDs to ${f}"

id_check() {
  if [ ! -z "${id}" ] && [ ! -z "${fc}" ] && [ ! -z "${rc}" ] && [ ! -z "${ct}" ]
  then
    if [ ${fc} -eq 0 ] && [ ${rc} -eq 0 ] && [ ${ct} -lt ${mt} ]
    then
      echo "${id}" | tee -a "${f}"
    fi
  fi
}

cat "${infile}" | \
jq -r '.[] | .[] | .id + "@" + .favorite_count + "@" + .retweet_count + "@" + .created_at' 2>/dev/null | while read line
do
  id="$(echo "${line}" | awk -F'@' '{print $1}')"
  fc="$(echo "${line}" | awk -F'@' '{print $2}')"
  rc="$(echo "${line}" | awk -F'@' '{print $3}')"
  ct="$(date -d "$(echo "${line}" | awk -F'@' '{print $4}')" +'%s')"
  id_check &
done

#t delete status -f $(cat $f | xargs -n100 -P$(grep -c proc /proc/cpuinfo)) 2>/dev/null
#/bin/rm -f "${f}"
