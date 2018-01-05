#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                            igor@comradegeneral.com
#                                 2018-01-04
# ----------------------------------------------------------------------------
# BTC price ticker and basic analysis
# ----------------------------------------------------------------------------
configure() {
  t=60
  tp=10800
  unset a b
  g="1 2 5 10 30 60"
  k="t:3 l:4 y:5"
}

aadd() {
  a+=("$(for i in spot sell buy; do grep -oP "(?<=\")[0-9]{1,}\.[0-9]{1,2}(?=\")" \
  <(curl -m10 -k -s0 https://api.coinbase.com/v2/prices/${i}?currency=USD 2>/dev/null); done | \
  sed 'N;N;s/\n/ /g' | awk -v d="$(date +'%Y-%m-%d %H:%M:%S')" '{print d,$0}')")
}

aprint() {
  for ((i = 0; i < ${#a[@]}; i++)) ; do echo "${a[$i]}" ; done
}

acount() {
  (( g = `printf '%s\n' ${#a[@]}` - 1 )) && echo ${g}
}

vset() {
  for i in $(echo ${g}); do
    for j in $(echo ${k}); do
      eval $(echo `awk -F: '{print $1}' <<<${j}`${i})=
      eval $(echo `awk -F: '{print $1}' <<<${j}`${i})=$(aprint | tail -${i} | head -1 | \
      awk -v f=`awk -F: '{print $2}' <<<${j}` '{print $f}')
    done
  done 2>/dev/null
}

dset() {
  for i in $(echo ${g}); do
    for j in $(echo ${k}); do
      eval $(echo d`awk -F: '{print $1}' <<<${j}`${i})=
      eval $(echo d`awk -F: '{print $1}' <<<${j}`${i})=$(echo "scale=2;$(eval echo \
      $`echo $(awk -F: '{print $1}' <<<${j})1`)-$(eval echo $`echo $(awk -F: '{print $1}' \
      <<<${j})${i}`)"|bc -l)
      eval $(echo dp`awk -F: '{print $1}' <<<${j}`${i})=
      eval $(echo dp`awk -F: '{print $1}' <<<${j}`${i})=$(echo "scale=2;100*($(eval echo $`echo $(awk -F: '{print $1}' \
      <<<${j})1`)-$(eval echo $`echo $(awk -F: '{print $1}' <<<${j})${i}`))/$(eval echo $`echo $(awk -F: '{print $1}' \
      <<<${j})${i}`)"|bc -l)%
    done
  done 2>/dev/null
}

dprint() {
  echo ". ΔSpot (%) ΔSell (%) ΔBuy (%)"
  for i in $(echo ${g} | awk '{$1=""; print $0}'); do
    echo -n "${i} "
    for j in $(echo ${k}); do
      eval echo $`echo d$(awk -F: '{print $1}' <<<${j})${i}` $`echo dp$(awk -F: '{print $1}' <<<${j})${i}`
    done | sed 'N;N;s/\n/ /g'
  done
}

rprint() {
  echo ""
  date +'%Y-%m-%d %H:%M:%S'
  echo "------- ------- ------- ------- ------- ------- -------"
  dprint | column -t
  echo "------- ------- ------- ------- ------- ------- -------"
  echo "${a[`acount`]}" | awk '{print "Now",$3,".",$4,".",$5}'
  dlt=$(echo "scale=2;$(echo ${a[`acount`]} | awk '{print $4}')-\
  $(echo \"${a[`acount`]}\" | awk '{print $3}' | sed 's/"//g')" | bc -l)
  pdlt=$(echo "scale=2;100*($(echo ${a[`acount`]} | awk '{print $4}')-\
  $(echo \"${a[`acount`]}\" | awk '{print $3}' | sed 's/"//g'))/\
  $(echo ${a[`acount`]} | awk '{print $4}')" | bc -l)
  dly=$(echo "scale=2;$(echo ${a[`acount`]} | awk '{print $5}')-\
  $(echo \"${a[`acount`]}\" | awk '{print $3}' | sed 's/"//g')" | bc -l)
  pdly=$(echo "scale=2;100*($(echo ${a[`acount`]} | awk '{print $5}')-\
  $(echo \"${a[`acount`]}\" | awk '{print $3}' | sed 's/"//g'))/\
  $(echo ${a[`acount`]} | awk '{print $5}')" | bc -l)
  dlty=$(echo "scale=2;${dlt}+${dly}" | bc -l)
  echo "δ ${dlty} . ${dlt} ${pdlt} ${dly} ${pdly}"
}

gplot() {
  aprint | tail -$(echo "scale=0;${tp}/${t}" | bc -l) | \
  gnuplot -e "set terminal dumb 96 28; unset key; set style data labels; set xdata time; \
  set xlabel 'Time'; set ylabel 'Spot'; set autoscale; set timefmt '%Y-%m-%d %H:%M:%S';
  set format x '%H:%M'; \
  plot '-' using 1:3:ytic(3) with histeps"
}

# RUNTIME
configure
for (( ; ; )); do
  aadd; vset; dset; clear; gplot; rprint | column -t; sleep ${t}
done
