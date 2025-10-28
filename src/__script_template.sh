#!/bin/bash

# __script_template.sh
#
# Script template and `bash-tools` demo.

# -------------------------- HEADER -------------------------------------------

set -eEo pipefail
shopt -s inherit_errexit

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/bash-tools.sh"

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename "${BASH_SOURCE[0]}") [options]
		Options:
		--the-secret-of-life ${underline}val${nounderline}   Why are we here? Just to suffer? (default: 42)
		--no-banner, -q            For the esteemed, joyless professional
		--help, -h                 Show this message
	EOF
}

# `getopt` arg parsing
# see: /usr/share/doc/util-linux/examples/getopt-example.bash

_parsed_args=$(getopt \
	--options='h,q' \
	--longoptions='help,the-secret-of-life:,no-banner' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

the_secret_of_life=42
no_banner=false

while true; do
	case "$1" in
	--the-secret-of-life)
		the_secret_of_life="$2"
		shift 2
		continue
		;;
	-q | --no-banner)
		no_banner=true
		shift 1
		continue
		;;
	-h | --help)
		show_usage
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown argument: $1"
		exit 1
		;;
	esac
done

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_host 'ARPANET'
assert_not_sourced

reset_checks
check_is_positive_integer the_secret_of_life
check_is_boolean no_banner
check_is_defined USER

for _command in awk grep curl sleep; do
	check_command_exists_on_path _command
done
print_failed_checks --error || exit

# -------------------------- BANNER -------------------------------------------

if [[ $no_banner == false ]]; then
	# see: https://www.asciiart.eu/text-to-ascii-art
	show_banner "${theme_value}${bold}" <<'EOF'
    __               __          __              __    
   / /_  ____ ______/ /_        / /_____  ____  / /____
  / __ \/ __ `/ ___/ __ \______/ __/ __ \/ __ \/ / ___/
 / /_/ / /_/ (__  ) / / /_____/ /_/ /_/ / /_/ / (__  ) 
/_.___/\__,_/____/_/ /_/      \__/\____/\____/_/____/  
EOF

	# -------------------------- PREAMBLE ---------------------------------------

	cat <<-EOF

	This file is a starter template for new scripts, and a light demo of ${theme_value}bash-tools${color_reset}.
	EOF
	press_any_key_to_continue
fi

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ ! -d "$this_dir" ]]; then
	printwarn "Existential crisis detected!"
	continue_or_exit
fi

# -------------------------- EXECUTION ----------------------------------------

trap 'on_err' ERR

printinfo "Hello, ${theme_value}$USER${color_reset}!"
if yes_or_no --default-yes "Can I tell you something?"; then
	printwarn "The secret of life is: ${theme_value}$the_secret_of_life${color_reset}"
fi

# -------------------------- POSTCONDITIONS -----------------------------------

printinfo -n "We are feeling..."
sleep 1
print_ok
