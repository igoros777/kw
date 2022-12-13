#!/bin/bash
export WWW_HOME="www.google.com/"
if [ $# -eq 0 ]
then
	echo 'Usage: imdb "Movie Title (Year)"'
	exit 1
else
	y=$(echo "${@}" | sed -E 's/[()]//g' | awk '{print $NF}' | grep -oE "[0-9]{4}")
	t=$(echo "${@}" | sed -E 's/[()]//g' | sed -E 's/ [0-9]{4}$//g' | sed -r 's/  */\+/g;s/\&/%26/g;s/\++$//g' | sed 's/ /\%20/g')
fi

configure() {
	tmpfile="/tmp/imdb-mf_${RANDOM}.tmp"
	#LYNX="lynx -connect_timeout=10 --source"
	#LYNX="curl -m10 -k -s0"
	LYNX="wget --max-redirect=30 --no-check-certificate --timeout=1 --tries=5 --retry-connrefused -U \"Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)\" -qO-"
	base_url_imdb="https://www.imdb.com/search/title"
	base_url_google="https://www.google.com/search"
}

cleanup() {
	if [ -f "${tmpfile}" ]
	then
		/bin/rm -f "${tmpfile}"
	fi
}

parse_imdb() {
	year="$(grep -oP "(?<=\<title\>).*(?=\</title\>)" $tmpfile | grep -oP "(?<=\()[0-9]{4}(?=\))" | head -1)"
	title="$(grep -oP "(?<=\<meta property=\"og:title\" content=\").*(?= - IMDb\"/\>\<meta property=\"og:description\")" $tmpfile | sed -r 's/ \([0-9]{4}\)//g' | recode html)"


	temp="$(grep -oP "(?<=property=\"og:description\" content=\").*(?=\"\/><meta property=\"og:type\")" $tmpfile)"
	director="$(echo ${temp} | grep -oP "(?<=Directed by ).*?(?=\. With)")"
	cast="$(echo ${temp} | grep -oP "(?<=\. With ).* ?(?=\. [A-Z0-9])" | sed -r 's/([A-Z]{1})\./\1@/g' | awk -F'.' '{print $1}' | sed -r 's/@/\./g')"
	plot="$(echo ${temp} | sed -r "s/${cast}\. /@/g" | awk -F'@' '{print $NF}')"
	rating="$(grep -oP "(?<=,\"ratingValue\":)[0-9]{1}(\.[0-9]{1})?(?=},)" $tmpfile)"
}

get_imdb() {
	if [ ! -z "${y}" ]
	then
		l=$(${LYNX} "https://www.imdb.com/search/title?release_date=${y},${y}&title=${t}&title_type=feature" | grep -m1 -oP "(?<=id=\")[a-z]{2}[0-9]{4,}(?=\|imdb)")
		if [ -z "${l}" ]
		then
			l=$(${LYNX} "https://www.imdb.com/search/title?release_date=${y},${y}&title=${t}&title_type=tv" | grep -m1 -oP "(?<=id=\")[a-z]{2}[0-9]{4,}(?=\|imdb)")
		fi
		${LYNX} "https://www.imdb.com/title/${l}/" > ${tmpfile} 2> /dev/null
	else
		${LYNX} "https://www.google.com/search?q=site:imdb.com+%22${t}%22&btnI" > ${tmpfile} 2> /dev/null
	fi
	parse_imdb
}

get_imdb2() {
	if [ -z "${title}" ]
	then
		if [ -z "${year}" ]
		then
			m=$(echo "${l}" | sed 's/ [Aa]nd / \& /g')
			${LYNX} "https://www.imdb.com/title/${m}/" > ${tmpfile} 2> /dev/null
			parse_imdb
		fi
	fi
}

get_imdb3() {
	if [ -z "${title}" ]
	then
		if [ -z "${year}" ]
		then
			#${LYNX} "https://www.google.com/search?q=site:imdb.com+%22${t}%22&btnI" > ${tmpfile} 2> /dev/null
			${LYNX} "$(${LYNX} "https://www.google.com/search?q=site:imdb.com+${t} (${y})&btnI" 2>/dev/null | grep -oE "(https?|ftps?)://[^\<\>\"\' ]+" | grep imdb | tail -1)" > ${tmpfile} 2> /dev/null
			parse_imdb
		fi
	fi
}

print_imdb() {
	if [ -z "${year}" ]
	then
		echo "Scraped the bottom of the pickle barrel but came up dry. Check the title and provide release year."
	else
		echo -e "Title:\t${title}"
		echo -e "Year:\t${year}"
		echo -e "Rating:\t${rating}"
		echo -e "Dir:\t${director}"
		echo -e "Cast:\t${cast}"
		echo -e "Plot:\t${plot}"
	fi
}

# RUNTIME
# ---------------------------

configure
cleanup
#get_imdb
#parse_imdb
#get_imdb2
get_imdb3
print_imdb
cleanup
