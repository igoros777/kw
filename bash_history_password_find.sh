#!/bin/bash
# Up to how many time do you think a user might enter his password in plain text in shell?
# This is to exclude some password-like strings in various log files that appear on a regular basis.
stupid_limit=5

# This is the regex that matches what may very well be a password
include_string="(?=[a-zA-Z0-9\!#@$?]{8,}$)(?=.*?[a-z])(?=.*?[A-Z])(?=.*?[0-9]).*"

# This regex excludes certain strings that look like passwords but you already know they aren't.
# Feel free to modify this to better match your environment.
exclude_string="11gSoftwareR4|Xms1536m|(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|\
Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)([0-9]{1,})?20[0-9]{2}"

# Here we search a few directories commonly containing logs and shell history files. Search depth is limited,
# so not to go down some NFS-mounted rabbit hole. Here we're looking specifically for users' .bash_history
# and the primary system log. You can add application and system daemon  logs as you need.
find / /home /var/log -mindepth 1 -maxdepth 3 -mount -type f -name "\.bash_history" -o -name "messages" | while read i
do
   # If something is matched
   if [ $(egrep -vi "${exclude_string}" "${i}" | grep -cP "${include_string}") -gt 0 ]
   then
     # Take a closer look
     egrep -vi "${exclude_string}" "${i}" | grep -oP "${include_string}" | sort -u | while read p
     do
       # Does it appear too often to be a user mistake?
       if [ $(grep -c "${p}" "${i}") -lt ${stupid_limit} ]
       then
         # If it looks just right, print the suspected password along with some other details
         echo "$(stat -c %U" "%y" "%n "${i}") ${p}"
         # This is an optional section commented out by default to reduce clutter. This command will
         # grep for an example of the password and a few lines before and after to put things in context
         #echo "-------------------------------------------------"
         #grep -m1 -B4 -A4 "${p}" "${i}"
         #echo "-------------------------------------------------"
         #echo ""
       fi
     done
   fi
done
