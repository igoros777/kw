#!/bin/bash
infile=$1
if [ -z "$infile" ]; then
    echo "Usage: $0 <infile>"
    exit 1
fi
if [ ! -f "$infile" ]; then
    echo "Error: $infile not found."
    exit 1
fi
common_word_list_01="$(mktemp)"
common_word_list_01_url="https://gist.githubusercontent.com/igoros777/e6ae5761ef6635c61eb9bed661f0d0c1/raw/98d35708fa344717d8eee15d11987de6c8e26d7d/1-1000.txt"
curl -m10 -k -s0 -o "$common_word_list_01" "$common_word_list_01_url"
if [ ! -s "$common_word_list_01" ]; then
    echo "Error: failed to download $common_word_list_01_url"
    exit 1
fi
tmpfile="$(mktemp)"

common_word_list_custom_01="$HOME/common_word_list_custom_01.txt"
if [ -f "$common_word_list_custom_01" ]; then
    cat "$common_word_list_custom_01" >> "$common_word_list_01"
    sort -u -o "$common_word_list_01" "$common_word_list_01"
fi

python3 <<EOF | column -t > "${tmpfile}"
import nltk
from nltk.tokenize import word_tokenize
from collections import Counter

try:
  nltk.data.find('tokenizers/punkt')
except LookupError:
  nltk.download('punkt')

with open('$infile', 'r') as f:
    text = f.read().lower()

with open('$common_word_list_01', 'r') as f:
    common_words = f.read().splitlines()

tokens = word_tokenize(text)
filtered_tokens = [word for word in tokens if word.isalpha() and not word in common_words]
counter = Counter(filtered_tokens)
overused_words = counter.most_common()

grouped_words = {}
for word, count in overused_words:
    if count in grouped_words:
        grouped_words[count].append(word)
    else:
        grouped_words[count] = [word]

for count in sorted(grouped_words.keys(), reverse=True):
    words = sorted(grouped_words[count])
    for word in words:
      if len(word) > 3 and count >= 2:
        print(f'{word}: {count}')
EOF

WN="$(which wn)"
if [ -z "$WN" ]; then
    cat "${tmpfile}"
else
    while read -r line; do
        word=$(echo "$line" | awk -F: '{print $1}')
        synonyms="$(${WN} "${word}" -synsn -synsv -synsr -synsa | 
            awk '/^Sense [0-9]+/{getline; split($0, a, " "); print a[1], a[2], a[3], a[4]}' | 
            sed 's/,$//g' | 
            awk 'BEGIN{RS=ORS="\n"} 
                { 
                    gsub(/^ +| +$/, "", $0); 
                    n = split($0, words, ", "); 
                    for (i=1; i<=n; i++) {
                        word = words[i];
                        if (!(word in seen)) {
                            seen[word]=1; 
                            print word;
                            if (++count == 10) exit;
                        }
                    }
                }' | paste -sd, - | sed 's/,/, /g')"
        echo -e "${line}\t${synonyms}"
    done < "${tmpfile}"
fi


/bin/rm -f "$common_word_list_01" "$tmpfile"
