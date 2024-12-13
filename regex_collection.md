## Regex Collection

Just a small collection of POSIX regular expressions that may come in handy for writing sysadmin scripts.

### The basics

```bash
.           Match any single character
^           Match the empty string at the beginning of a line
$           Match the empty string at the end of a line
A           Match an upper-case letter A
a           Match a lower-case letter a
\d          Match any single digit
\D          Match any single non-digit
\w          Match any single alphanumeric character
[A-E]       Match any upper-case A, B, C, D, or E
[^A-E]      Match any character except upper-case A, B, C, D, or E
X?          Match no or upper-case letter X
X*          Match zero or more capital X
X+          Match one or more capital X
X{n}        Match n occurences of capital X
X{n,m}      Match at least n but no more than m occurences of capital X
(abc|def)+  Match one or more occurences of abc and/or def sub-strings
```

### Simplified IP form

```bash
grep -oE "([0-9]{1,3}\.){3}([0-9]{1,3})"
```

### Four parts of the IP

```bash
grep -oE "([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})"
```

### Valid IPv4

```bash
grep -oE "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
```

### Valid IPv6

```bash
grep -oE "(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"
```

### Private Subnets

~~~bash
grep -oE "(^127\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)"
~~~

### Exclude Private Subnets and Default Route

~~~bash
grep -vE "(^0\.)|(^127\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)"
~~~

### MAC Address

```bash
grep -oE '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}'
```

### Simplified email address

```bash
grep -oE "\w[a-zA-Z0-9.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\w"
```

### Simplified email address (another way)

```bash
grep -oE "\w[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\w"
```

### Simplified email address (yet another way)

~~~bash
grep -oP "([\w.-]+)@([\w.-]+)\.([a-zA-Z.]{2,6})" /var/log/maillog
~~~

### A slightly cleverer email address grabber

```bash
grep -oP '(?i)\b[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}\b'
```

### Valid RFC email address

```bash
grep -Po "([^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+|\\x22([^\\x0d\\x22\\x5c\\x80-\\xff]|\\x5c[\\x00-\\x7f])*\\x22)(\\x2e([^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+|\\x22([^\\x0d\\x22\\x5c\\x80-\\xff]|\\x5c\\x00-\\x7f)*\\x22))*\\x40([^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+|\\x5b([^\\x0d\\x5b-\\x5d\\x80-\\xff]|\\x5c[\\x00-\\x7f])*\\x5d)(\\x2e([^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+|\\x5b([^\\x0d\\x5b-\\x5d\\x80-\\xff]|\\x5c[\\x00-\\x7f])*\\x5d))*"
```

### Something that looks like a hostname/domain name

```bash
grep -oP "\b(([a-zA-Z](-?[a-zA-Z0-9])*)\.)*[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}\b"
```

### Common Unix- and Windows-style usernames

```bash
grep -oP "(?<=\W)[a-z-]{5,16}([0-9]{1,2})?(?=\W)"
```

### Common Windows domain usernames (i.e. DOMAIN\username)

~~~bash
grep -oP '\b(([a-zA-Z](-?[a-zA-Z0-9])*)\.)*[a-zA-Z](-?[a-zA-Z0-9])+(\.[a-zA-Z]{2,})?\\[a-zA-Z]{5,16}([0-9]{1,2})?\b'
~~~

### Match a Hex value

```bash
grep -oE "#?([a-f0-9]{6}|[a-f0-9]{3})"
```

### Match HTML tags

```bash
grep -oE "<([a-z]+)([^<]+)*(?:>(.*)<\/\1>|\s+\/>)"
```

### Simplified HTTP(S) and FTP(S) links

```bash
grep -oE "(https?|ftps?)://[^ ]+"
```

### More complete HTTP(S) and FTP(S) links

```bash
grep -oE "(https?|ftps?)://[^\<\>\"\' ]+"
```

### Another way to extract URLs

```bash
sed -n 's/.*href="\([^"]*\).*/\1/p'
```

### Extract URLs using `awk`

~~~bash
awk 'BEGIN{
RS="</a>"
IGNORECASE=1
}
{
  for(k=1;k<=NF;k++){
    if ( $k ~ /href/){
      gsub(/.*href=\042/,"",$k)
      gsub(/\042.*/,"",$k)
      print $(k)
    }
  }
}'
~~~

### Extract executables with paths from output of `ps aux` 

~~~bash
grep -oP '(?<=:[0-9]{2} )(/[^/ ]*)+/?(?= )'
~~~

### Extract shell script paths and names

~~~bash
grep -oP '(?<=\s)(/[^/ ]*)+/?\.((b|d)?a|(m|pd)?k|z)?sh(?=(\s|$))'
~~~

### Invalid Windows filename characters

```bash
grep -oP '[*<>=+"\\/,.:;]'
```

### Simplified SSN

```bash
grep -oP "\d{3}-\d{2}-\d{4}"
```

### More rigorous SSN validation

```bash
grep -oP '(?!\b(\d)\1+-(\d)\1+-(\d)\1+\b)(?!123-45-6789|219-09-9999|078-05-1120)(?!666|000|9\d{2})\d{3}-(?!00)\d{2}-(?!0{4})\d{4}'
```

### Match a 10-digit US phone number

```bash
grep -o '\(([0-9]\{3\})\|[0-9]\{3\}\)[ -]\?[0-9]\{3\}[ -]\?[0-9]\{4\}'
```

### Match CVE number

```bash
grep -o 'CVE-[0-9]{4}-[0-9]{1,5}'
```

### Non-capturing groups

```bash
# Extract a four-digit number in parentheses from string 2013 Monkeys in 1999 (2014).txt
echo "2013 Monkeys in 1999 (2014).txt" | grep -oP "(?<=\()[0-9]{4}(?=\))"
```

### Combine multiple non-capturing groups

```bash
# Print 'word1 word3'
i="tag1 word1 tag2 word2 tag3 word3 tag4"
echo $i | grep -oP '(?<=tag[13] )\w+(?= tag[24])' | paste -s -d" "
```

### Similar to above

```bash
# Print 'word1 word3'
i="tag1 word1 tag2 word2 tag3 word3 tag4"
echo $i | grep -oP '(?<=tag[13] )\w+(?= tag[24])' | paste -s -d" "
```

### Also similar to above

```bash
# Print 'word1 word3'
i="tag1 word1 tag2 word2 tag3 word3 tag4"
echo $i | tee >(grep -oP '(?<=tag1 )\w+(?= tag2)') >(grep -oP '(?<=tag3 )\w+(?= tag4)') | sed '1d;1!G;h;$!d' | paste -s -d" "
```

### Find all links in a file

```bash
egrep -IRo '(((http(s)?|ftp|telnet|news|gopher)://|mailto:)[^()<"'''[:space:]]+)'
```

### Check if variable is integer

~~~bash
re='^[0-9]+$'
if ! [[ ${var} =~ ${re} ]] ; then
   echo "error: Not an integer" >&2; exit 1
fi
~~~

### Check if variable is integer or decimal

~~~bash
re='^[0-9]+([.][0-9]+)?$'
if ! [[ ${var} =~ ${re} ]] ; then
   echo "error: Not an integer or decimal" >&2; exit 1
fi
~~~

### Check if variable is integer or decimal, either positive or negative

~~~bash
re='^[+-]?[0-9]+([.][0-9]+)?$'
if ! [[ ${var} =~ ${re} ]] ; then
   echo "error: Not an integer or decimal, either positive or negative" >&2; exit 1
fi
~~~

### Common numeric ranges

```bash
000..255        "([01][0-9][0-9]|2[0-4][0-9]|25[0-5])"
0 or 000..255   "([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])"
0 or 000..127   "(0?[0-9]?[0-9]|1[01][0-9]|12[0-7])"
0..999          "([0-9]|[1-9][0-9]|[1-9][0-9][0-9])"
000..999        "[0-9]{3}"
0 or 000..999   "[0-9]{1,3}"
1..999          "([1-9]|[1-9][0-9]|[1-9][0-9][0-9])"
001..999        "(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])"
1 or 001..999   "(0{0,2}[1-9]|0?[1-9][0-9]|[1-9][0-9][0-9])"
0 or 00..59     "[0-5]?[0-9]"
0 or 000..366   "(0?[0-9]?[0-9]|[1-2][0-9][0-9]|3[0-5][0-9]|36[0-6])"
1..12           "(1[0-2]|[1-9])"
1..24           "(2[0-4]|1[0-9]|[1-9])"
1..31           "(3[01]|[12][0-9]|[1-9])"
1..53           "(5[0-3]|[1-4][0-9]|[1-9])"
0..100          "(100|[1-9]?[0-9])"
1..100          "(100|[1-9][0-9]?)"

# ---------------------------------------------------------

Positive Integers               "\d+"
Negative Integers               "-\d+"
Integer                         "-{0,1}\d+"
Positive Number                 "\d*\.{0,1}\d+"
Negative Number                 "-\d*\.{0,1}\d+"
Positive or Negative Number     "-{0,1}\d*\.{0,1}\d+"
Phone number                    "\+?[\d\s]{3,}"
Year 1900..2099                 "(19|20)[\d]{2,2}"
Binary number                   "[01]{8}+"
```

### ASCII ranges

```bash
# All Printable Characters in the ASCII Table

grep -E "[ -~]"

# All Printable Characters in the ASCII Table, Except the Space Character

grep -E "[!-~]"

# All English Consonants

grep -E "[b-df-hj-np-tv-z]"

# All Special Characters in the ASCII Table

grep -oP '(?![a-zA-Z0-9])[!-~]'

# All Special Characters in the ASCII Table Without Using Lookahead

grep -oP '[!-/:-@\[-`{-~]'

# Alphanumeric Characters

grep -E "[^\W_]"
```

### Foreign Languages

```bash
# French
[a-zA-ZàâäôéèëêïîçùûüÿæœÀÂÄÔÉÈËÊÏÎŸÇÙÛÜÆŒ]

# German
[a-zA-ZäöüßÄÖÜẞ]

# Polish
[a-pr-uwy-zA-PR-UWY-ZąćęłńóśźżĄĆĘŁŃÓŚŹŻ]

# Italian
[a-zA-ZàèéìíîòóùúÀÈÉÌÍÎÒÓÙÚ]

# Spanish
[a-zA-ZáéíñóúüÁÉÍÑÓÚÜ]

# Russian
[юяжертыуиопшщэасдфгчйклзхцвбнмьЬЮЯЖЕРТЫУИОПШЩЭАСДФГЧЙКЛЗХЦВБНМ]

```

### Match lines where an upper-case word later also appears in lower-case

```bash
grep -P '(\b[A-Z]{2,}+\b)(?=.*(?=\b[a-z]{2,}+\b)(?i)\1)'
```

### Grab 7-character words containing string "kr"

```bash
grep -Po '(?=\b\w{7}\b)\w*?kr\w*'
```

### Find lines with consecutive repeating words

```bash
grep -P '\b([[:alpha:]]+)\s+\1'
```

### Grab dates in YYYY-mm-dd format

```bash
grep -Po "(19|20)\d\d([- /.])(0[1-9]|1[012])\2(0[1-9]|[12][0-9]|3[01])"
```

### Grab dates in mm-dd-YYYY

```bash
grep -Po "(0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])[- /.](19|20)\d\d"
```

### Grab dates in dd-mm-YYYY format

```bash
grep -Po "(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.](19|20)\d\d"
```

### Grab a valid date in mm/dd/YYYY [HH:MM:SS am/pm] format

```bash
grep -Po "\b(((((0[13578])|([13578])|(1[02]))[\-\/\s]((0[1-9])|([1-9])|([1-2][0-9])|(3[01])))|((([469])|(11))[\-\/\s]?((0[1-9])|([1-9])|([1-2][0-9])|(30)))|((02|2)[\-\/\s]?((0[1-9])|([1-9])|([1-2][0-9]))))[\-\/\s]?\d{4})(\s(((0[1-9])|([1-9])|(1[0-2]))\:([0-5][0-9])((\s)|(\:([0-5][0-9])\s))([AM|PM|am|pm]{2,2})))?\b"
```

### Grab time in 24-hour format with optional seconds

```bash
grep -Po "\b(([0-1]?[0-9])|([2][0-3])):([0-5]?[0-9])(:([0-5]?[0-9]))?\b"
```

### Grab date in "DD-MON-YYYY" format

```bash
grep -iPo "\b((31(?! (FEB|APR|JUN|SEP|NOV)))|((30|29)(?! FEB))|(29(?= FEB (((1[6-9]|[2-9]\d)(0[48]|[2468][048]|[13579][26])|((16|[2468][048]|[3579][26])00)))))|(0?[1-9])|1\d|2[0-8])[- /.](JAN|FEB|MAR|MAY|APR|JUL|JUN|AUG|OCT|SEP|NOV|DEC)[- /.]((1[6-9]|[2-9]\d)\d{2})\b"
```

------

## 