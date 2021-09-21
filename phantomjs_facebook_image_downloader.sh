#!/bin/bash

configure() {
  login_url="https://www.facebook.com/login/"
  ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36"
  basedir=~/phantomjs_facebook
  project="$(shuf -i 100000-999999 -n 1)"
  mkdir -p ${basedir}/tmp
  mkdir -p ${basedir}/cookies
  if [ ! -d "${basedir}/scripts" ]; then
    mkdir -p ${basedir}/scripts
    for i in facebook_login.js phantomjs_render.js; do
      curl -s0 -k -q -o ${basedir}/scripts/${i} https://raw.githubusercontent.com/igoros777/kw/master/${i}
    done
  fi
  mkdir -p ${basedir}/data/${project}
  cookies=${basedir}/cookies/phantomjs_cookies.txt
  progress=${basedir}/data/${project}/progress.txt
  urls="${basedir}/links"
  if [ ! -f "${urls}" ]; then 
    echo "URL list not found: ${urls}"
    exit 1
  else
    link_count="$(wc -l "${urls}" | awk '{print $1}')"
  fi
  phantomjs --load-images=true --local-storage-path=/tmp --disk-cache=true --disk-cache-path=/tmp --cookies-file=${cookies} \
  --ignore-ssl-errors=true --ssl-protocol=any --web-security=true ${basedir}/scripts/facebook_login.js "${ua}" "${login_url}" 2>/dev/null
}

i=1
image_get() {
  cat "${urls}" | while read url; do
    echo -e "${i}/${link_count}:\t${url}"
    (( i = i + 1 ))
    phantomjs --load-images=true --local-storage-path=/tmp --disk-cache=true --disk-cache-path=/tmp --cookies-file=${cookies} \
    --ignore-ssl-errors=true --ssl-protocol=any --web-security=true ${basedir}/scripts/phantomjs_render.js "${ua}" "${url}" ${basedir}/tmp/${project}.png 2>/dev/null 1>&2
    
    if [ -f ${basedir}/tmp/temp.html ]; then
      ext="$(grep -oP "(?<=\.)[a-z]{3,4}(?=\?_nc_cat)" ${basedir}/tmp/temp.html | head -1)"
      wget -q "$(grep -oP "(?<=\"image\":\{\"uri\":\").*(?=\",\"width\")" ${basedir}/tmp/temp.html | \
      sed 's@\\@@g')" -O ${basedir}/data/${project}/${project}_$(shuf -i 100000-999999 -n 1).${ext} 2>/dev/null 1>&2
      /bin/rm -f ${basedir}/tmp/temp.html 2>/dev/null
    fi
  done
}

# RUNTIME

configure
image_get
