#!/usr/bin/env bash
#
# phonewords.sh - translate between text and 1990s multi-tap phone keypad digits.
#
#   $ ./phonewords.sh lasagna
#   555 2 7777 2 4 66 2
#   $ ./phonewords.sh 555 2 7777 2 4 66 2
#   lasagna
#   $ echo 'hello world' | ./phonewords.sh
#   44 33 555 555 666 0 9 666 777 555 3
#
# Keypad: 2=abc 3=def 4=ghi 5=jkl 6=mno 7=pqrs 8=tuv 9=wxyz 0=space *=+ #=#
# Each keypress group is separated by a space - the pause you'd take between
# taps so the phone knows one letter ended and the next began. One extra tap
# past the last letter on a key gives you the digit itself (22222 -> "2").
#
# Direction is auto-detected: any letter in the input means encode, otherwise
# decode. Force it with -e / --encode or -d / --decode.

set -uo pipefail

PAD=( "0: " "2:abc" "3:def" "4:ghi" "5:jkl" "6:mno" "7:pqrs" "8:tuv" "9:wxyz" )

usage() {
	sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
}

warn() {
	printf '%s: %s\n' "${0##*/}" "$1" >&2
}

# repeat CHAR COUNT
repeat() {
	local s="" i
	for ((i = 0; i < $2; i++)); do
		s+="$1"
	done
	printf '%s' "$s"
}

encode() {
	local text=$1 out="" i c e d letters head grp
	text=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')

	for ((i = 0; i < ${#text}; i++)); do
		c=${text:i:1}
		grp=""

		case $c in
			'+') grp='*' ;;
			'#') grp='#' ;;
			'1') grp='1' ;;
		esac

		if [ -z "$grp" ]; then
			for e in "${PAD[@]}"; do
				d=${e%%:*}
				letters=${e#*:}
				head=${letters%%"$c"*}
				if [ "$head" != "$letters" ]; then
					grp=$(repeat "$d" $((${#head} + 1)))
					break
				fi
			done
		fi

		# A literal digit is one tap past the last letter on its own key.
		if [ -z "$grp" ] && [ "$c" != "${c#[0-9]}" ]; then
			for e in "${PAD[@]}"; do
				if [ "${e%%:*}" = "$c" ]; then
					grp=$(repeat "$c" $((${#e} - 1)))
					break
				fi
			done
		fi

		if [ -z "$grp" ]; then
			warn "no key for '$c', skipped"
			continue
		fi

		out+="${out:+ }$grp"
	done

	printf '%s\n' "$out"
}

decode() {
	local out="" g e d n len letters idx c
	set -f # a lone '*' group must not glob against the working directory
	# shellcheck disable=SC2086 # deliberate word splitting on the tap groups
	for g in $1; do
		d=${g:0:1}
		n=${#g}

		if [ -n "${g//"$d"/}" ]; then
			warn "mixed keypress group '$g', skipped"
			continue
		fi

		letters=""
		for e in "${PAD[@]}"; do
			if [ "${e%%:*}" = "$d" ]; then
				letters=${e#*:}
				break
			fi
		done

		if [ -z "$letters" ]; then
			case $d in
				'*') c='+' ;;
				'#') c='#' ;;
				'1') c='1' ;;
				*)
					warn "not a key: '$g', skipped"
					continue
					;;
			esac
		else
			# Taps wrap around, and the tap after the last letter is the digit.
			len=${#letters}
			idx=$(((n - 1) % (len + 1)))
			if [ "$idx" -eq "$len" ]; then
				c=$d
			else
				c=${letters:idx:1}
			fi
		fi

		out+="$c"
	done
	set +f

	printf '%s\n' "$out"
}

translate() {
	local line=$1
	case $MODE in
		encode) encode "$line" ;;
		decode) decode "$line" ;;
		*)
			if [ "$line" != "${line#*[A-Za-z]}" ]; then
				encode "$line"
			else
				decode "$line"
			fi
			;;
	esac
}

MODE=auto
case ${1-} in
	-e | --encode) MODE=encode; shift ;;
	-d | --decode) MODE=decode; shift ;;
	-h | --help) usage; exit 0 ;;
esac

if [ $# -gt 0 ]; then
	translate "$*"
else
	while IFS= read -r line; do
		translate "$line"
	done
fi
