#!/bin/bash
# Parse Twitter's 'tweet.js' data file and delete old posts that have no likes or retweets
f="$(mktemp)"
mt="$(date -d '3 months ago' +'%s')"
id_check() {
  if [ ! -z "${id}" ] && [ ! -z '${fc}' ] && [ ! -z "${rc}" ] && [ ! -z "${ct}" ]
  then
    if [ ${fc} -eq 0 ] && [ ${rc} -eq 0 ] && [ ${ct} -lt ${mt} ]
    then
      echo "${id}" | tee -a "${f}"
    fi
  fi
}
cat tweet.js | \
jq -r '.[] | .id + "@" + .favorite_count + "@" + .retweet_count + "@" + .created_at' 2>/dev/null | while read line
do
  id="$(echo "${line}" | awk -F'@' '{print $1}')"
  fc="$(echo "${line}" | awk -F'@' '{print $2}')"
  rc="$(echo "${line}" | awk -F'@' '{print $3}')"
  ct="$(date -d "$(echo "${line}" | awk -F'@' '{print $4}')" +'%s')"
  id_check &
done
t delete status -f $(cat $f | xargs -n100 -P$(grep -c proc /proc/cpuinfo)) 2>/dev/null
/bin/rm -f "${f}"
