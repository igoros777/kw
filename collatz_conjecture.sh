#!/bin/bash
# Assign command-line argument to variable n
# Exit if n is unassigned or not a positive integer
n="${1}"
if [[ -z "${n}" ]] || ! [[ "${n}" =~ ^[0-9]+$ ]]
then
  exit 1
else
  m=${n}
fi

# If the number is positive, then divide it by two
# Otherwise multiply it by three and increment by one
calc() {
  awk '{ if ($0 % 2) {exit 1} else {exit 0}}' <<<${n} && \
  n=$(bc <<<"${n}/2") || \
  n=$(bc <<<"3*${n}+1")
}

# Display the current loop iteration and the value of n
show() {
  (( i = i + 1 ))
  echo "${m} ${i} ${n}"
}


i=0
while true; do
  # If length of n is greater then 1, continue running the loop
  if [ ${#n} -gt 1 ]; then
    calc && show
  else
    # If length of n is 1, continue running the loop until the
    # value of n is greater than 1
    while [ ${n} -gt 1 ]; do
      calc && show
    done
    # Once n is equal to 1, break the loop and exit the script
    break
  fi
done
