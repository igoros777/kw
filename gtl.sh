#!/bin/bash

while getopts ":hf:k:s:p:" OPTION
do
  case "${OPTION}" in
  h) cat << EOF
  Usage: gtl [option] [arg]
  Generate frequency histogram from log data.

  Options :
     -h : shows the help page
     -s [arg] : Specify sorting options (default is '-k1M -k2n -k3V')
     -f [arg] : Specify the fields to analyze (default is all)
     -k [arg] : Specify the field separator (default is space)
     -p [arg] : Specify the character position to summarize (default is 6)

  Example :
     gtl -f " " -p 6 -k "@" -s "-k1M -k2n -k3V"

EOF
     exit 0
     ;;
  f) f="${OPTARG}"
     ;;
  k) k="${OPTARG}"
     ;;
  s) s="${OPTARG}"
     ;;
  p) p="${OPTARG}"
    ;;
  \?) printf "%s\n" "Invalid option. Type gtl -h for help"
      exit 191
      ;;
  *) printf "%s\n" "Invalid argument. Type gtl -h for help"
     exit 192
      ;;
  esac
done

if [ -z "${f}" ]; then f=" "; fi
if [ -z "${p}" ]; then p=6; fi
if [ -z "${k}" ]; then k="@"; fi
if [ -z "${s}" ]; then s="-k1M -k2n -k3V"; fi

awk -F"$f" -v k=$k '{split(k,a,","); for (key in a) { printf $a[key]" " } print"\n"}' | \
grep . | \
sort ${s} | \
uniq -c -w${p} | \
gnuplot -e "set terminal dumb 84 28; unset key; set style data labels; set xdata time; set xlabel 'Timeline'; set ylabel 'Events'; set autoscale; set timefmt '%b %d'; plot '-' using 2:1:ytic(1) with histeps"
