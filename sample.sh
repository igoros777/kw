#!/bin/sh
i='^(-)?[0-9]+$'
if ! [[ $1 =~ $i ]] ; then
  echo "error: $1 is not an integer" >&2; exit 1
fi
if [ $1 -gt 0 ]; then
  echo "$1 is positive"
elif [ $1 -lt 0 ]; then
  echo "$1 is negative"
elif [ $1 -eq 0 ]; then
  echo "$1 is zero"
fi
