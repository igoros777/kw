#!/bin/bash
# Parse Twitter's 'tweet.js' data file and delete old posts that have no likes or retweets
# For details see https://www.igoroseledko.com/installing-t-cli-power-tool-for-twitter/
# Extract tweet.js from Twitter data archive and remove this string from it:
# window.YTD.tweet.part0 =
# Make sure the first line of the file now begins with a left square bracket [

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

line_parse() {
  read id <<<"$(cut -d@ -f1 <<<"${line}")"
  read fc <<<"$(cut -d@ -f2 <<<"${line}")"
  read rc <<<"$(cut -d@ -f3 <<<"${line}")"
  ct="$(date -d "$(cut -d@ -f4 <<<"${line}")" +'%s')"
  id_check &
}

jq -r '.[] | .[] | .id + "@" + .favorite_count + "@" + .retweet_count + "@" + .created_at' 2>/dev/null <"${infile}" | while read line
do
  line_parse &
done
#${T} delete status -f $(sort -u "${f}" | xargs -n100 -P$(grep -c proc /proc/cpuinfo)) 2>/dev/null
#/bin/rm -f "${f}"
