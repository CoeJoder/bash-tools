#!/bin/bash

# -------------------------- HEADER -------------------------------------------

# set -e

# this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
# source "$this_dir/../external/bash-tools/src/bash-tools.sh"

# function show_usage() {
# 	cat >&2 <<-EOF
# 		Usage: $(basename "${BASH_SOURCE[0]}") [options]
#		  Options:
# 		  --help, -h   Show this message
# 	EOF
# }

# _parsed_args=$(getopt \
# 	--options='h' \
# 	--longoptions='help' \
# 	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
# eval set -- "$_parsed_args"
# unset _parsed_args

# while true; do
# 	case "$1" in
# 	-h | --help)
# 		show_usage
# 		exit 0
# 		;;
# 	--)
# 		shift
# 		break
# 		;;
# 	*)
# 		printerr "unknown argument: $1"
# 		exit 1
# 		;;
# 	esac
# done

# -------------------------- PRECONDITIONS ------------------------------------

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

# -------------------------- POSTCONDITIONS -----------------------------------
