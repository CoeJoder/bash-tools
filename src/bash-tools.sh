#!/bin/bash
#
# bash-tools.sh
# A general-purpose library of useful bash functions and constants.
#
# Requires Bash 5.2+ and GNU getopt (util-linux).

# -------------------------- HEADER -------------------------------------------

# This file should be sourced; ignore unused variable warnings.
# shellcheck disable=SC2034

# Bash version check
if [[ -z "${BASH_VERSINFO[*]}" ]]; then
	echo "Error: this script must be run with Bash, not another shell." >&2
	exit 1
fi
if ((BASH_VERSINFO[0] < 5)) || ((BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] < 2)); then
	echo "Error: Bash 5.2 or newer is required (found ${BASH_VERSION})." >&2
	exit 1
fi

# GNU getopt check
if ! command -v getopt &>/dev/null; then
	echo "Error: GNU getopt required" >&2
	exit 1
else
	if getopt -T &>/dev/null; then
		echo "Error: your getopt is too old. Install util-linux to acquire GNU getopt." >&2
		exit 1
	elif [[ $? -ne 4 ]]; then
		echo "Error: your getopt is too old. Install util-linux to acquire GNU getopt." >&2
		exit 1
	fi
fi

# -------------------------- VARS ---------------------------------------------

# current log-level
export _BASHTOOLS_LOGLEVEL='info'

# set colors only if tput is available
if [[ $(command -v tput && tput setaf 1 2>/dev/null) ]]; then
	color_red=$(tput setaf 1)
	color_green=$(tput setaf 2)
	color_yellow=$(tput setaf 3)
	color_blue=$(tput setaf 4)
	color_magenta=$(tput setaf 5)
	color_cyan=$(tput setaf 6)
	color_white=$(tput setaf 7)
	color_darkgray=$(tput setaf 232)
	color_lightgray=$(tput setaf 245)
	color_reset=$(tput sgr0)
	bold=$(tput bold)
	underline=$(tput smul)
	nounderline=$(tput rmul)

	# TODO implement `set_theme`
	theme_filename="${color_green}"
	theme_value="${color_cyan}"
	theme_url="${color_blue}"
	theme_command="${color_lightgray}"
	theme_example="${color_lightgray}"
fi

# -------------------------- UTILITIES ----------------------------------------

# get a human-readable timestamp
function get_timestamp() {
	date "+%m-%d-%Y, %r"
}

# echo to stdout
function stdout() {
	echo "$@"
}

# echo to stderr
function stderr() {
	echo "$@" >&2
}

# common logging suffix for INFO messages
# TODO remove
function print_ok() {
	stderr "${color_green}OK${color_reset}"
}

# log levels
declare -ra _BASHTOOLS_LOGLEVELS_KEYS=(
	'trace' 'debug' 'info' 'warn' 'error' 'fatal'
)
declare -rA _BASHTOOLS_LOGLEVELS=(
	[${_BASHTOOLS_LOGLEVELS_KEYS[0]}]="10 $color_lightgray"
	[${_BASHTOOLS_LOGLEVELS_KEYS[1]}]="20 $color_darkgray"
	[${_BASHTOOLS_LOGLEVELS_KEYS[2]}]="30 $color_green"
	[${_BASHTOOLS_LOGLEVELS_KEYS[3]}]="40 $color_yellow"
	[${_BASHTOOLS_LOGLEVELS_KEYS[4]}]="50 $color_red"
	[${_BASHTOOLS_LOGLEVELS_KEYS[5]}]="60 ${color_red}${bold}"
)

# set the current log-level
function set_loglevel() {
	if (($# < 1)); then
		log error "Usage: set_loglevel <level>"
		return 255
	fi
	local log_level="${1,,}"  # lowercase
	local log_level_val
	if [[ "${_BASHTOOLS_LOGLEVELS[$log_level]+1}" ]]; then
		_BASHTOOLS_LOGLEVEL="$log_level"
	else
		log error "Invalid log-level: $log_level"
		return 1
	fi
}

# Print to stderr if log-level is sufficient.
#
# Examples:
#   log info "Nuclear launch detected."
function log() {
	if (($# < 1)); then
		log error "Usage: log <level> [message]"
		return 255
	fi
	local msg_level="${1,,}"  # lowercase
	shift
	local args=("$@")
	shift $#
	local msg_level_val
	local msg_level_col
	local log_level_val

	if [[ "${_BASHTOOLS_LOGLEVELS[$msg_level]+1}" ]]; then
		read -r log_level_val _ <<<"${_BASHTOOLS_LOGLEVELS[$_BASHTOOLS_LOGLEVEL]}"
		read -r msg_level_val msg_level_col <<<"${_BASHTOOLS_LOGLEVELS[$msg_level]}"
		if [[ "$msg_level_val" -ge "$log_level_val" ]]; then
			stderr -e "${msg_level_col}${msg_level^^}${color_reset} ${args[*]}"
		fi
	else
		log error "Invalid log-level: $msg_level"
		return 1
	fi
}

# Same as `log()` but message is passed via stdin.
#
# Examples:
#   logcat error <<-EOF
#   	Usage: $(basename "${BASH_SOURCE[0]}") [options]
#   	Options:
#   	  --arg1 value   First arg
#   	  --arg2 value   Second arg
#   EOF
function logcat() {
	log "$@" "$(cat)"
}

# Helper for TRACE logging of the call stack.
#
# Examples:
#   functrace "$@"
function functrace() {
	log trace "${FUNCNAME[1]} $*"
}

# Prints TRACE message to stderr.
# Styled like `log()` but prints regardless of log-level.
function printtrace() {
	local echo_opts='-e'
	if [[ $1 == '-n' ]]; then
		echo_opts='-en'
		shift
	fi
	stderr $echo_opts "${color_lightgray}TRACE ${color_reset}$*"
}

# Prints DEBUG message to stderr.
# Styled like `log()` but prints regardless of log-level.
function printdebug() {
	local echo_opts='-e'
	if [[ $1 == '-n' ]]; then
		echo_opts='-en'
		shift
	fi
	stderr $echo_opts "${color_darkgray}DEBUG ${color_reset}$*"
}

# Prints INFO message to stderr.
# Styled like `log()` but prints regardless of log-level.
function printinfo() {
	local echo_opts='-e'
	if [[ $1 == '-n' ]]; then
		echo_opts='-en'
		shift
	fi
	stderr $echo_opts "${color_green}INFO ${color_reset}$*"
}

# Prints WARN message to stderr.
# Styled like `log()` but prints regardless of log-level.
function printwarn() {
	local echo_opts='-e'
	if [[ $1 == '-n' ]]; then
		echo_opts='-en'
		shift
	fi
	stderr $echo_opts "${color_yellow}WARN ${color_reset}$*"
}

# Prints ERROR message, with optional error code, to stderr.
# Styled like `log()` but prints regardless of log-level.
#
# Examples:
#   `printerr "failed to launch"`
#   `printerr 2 "failed to launch"`
function printerr() {
	local code=$? msg
	if [[ $# -eq 2 ]]; then
		code=$1
		msg="$2"
		stderr -e "${color_red}ERROR ${code}${color_reset} $msg"
	elif [[ $# -eq 1 ]]; then
		msg="$1"
		stderr -e "${color_red}ERROR${color_reset} $msg"
	else
		log error "${color_red}ERROR${color_reset} Usage: printerr [code] msg"
		return 255
	fi
}

# Callback for ERR trap.  Exits the shell at completion.
#
# Examples:
#   `trap 'on_err' ERR
#   `trap 'on_err "failed to launch"' ERR`
#   `trap 'on_err 2 "failed to launch"' ERR`
function on_err() {
	local exit_status=$?
	local msg
	msg="at line $(caller)"
	if [[ $# -eq 2 ]]; then
		exit_status=$1
		msg="$2"
	elif [[ $# -eq 1 ]]; then
		exit_status=$1
	fi
	log error "$exit_status" "$msg"
	exit "$exit_status"
}

# `read` but allows a default value
function read_default() {
	if [[ $# -ne 3 ]]; then
		stderr "Usage: read_default description default_val outvar"
		return 255
	fi
	local description="$1" default_val="$2" outvar="$3" val
	echo -e "${description} (default: ${theme_example}$default_val${color_reset}):${theme_value}"
	IFS= read -r val
	if [[ -z $val ]]; then
		val="$default_val"
		# cursor up 1, echo value
		echo -e "\e[1A${val}"
	fi
	echo -en "${color_reset}"
	printf -v "$outvar" "%s" "$val"
}

# `read` but stylized like `read_default`
function read_no_default() {
	if [[ $# -ne 2 ]]; then
		stderr "Usage: read_no_default description outvar"
		return 255
	fi
	local description="$1" outvar="$2" val
	IFS= read -rp "${description}: ${theme_value}" val
	echo -en "${color_reset}"
	printf -v "$outvar" "%s" "$val"
}

# if directory doesn't exist, ask if it should be created, and chmod it
function ask_to_create_directory_if_not_exist() {
	if [[ $# -lt 1 ]]; then
		stderr "Usage: ask_to_create_directory_if_not_exists <directory> [permissions=700]"
		return 255
	fi
	local -r _dir="$1"
	shift
	local -r _perms="${1:-700}"

	# ensure config directory exists and is read/writable
	if [[ ! -d "$_dir" ]]; then
		log warn "directory not found: ${theme_filename}$_dir${color_reset}"
		yes_or_no --default-yes "Create it?" || return
		mkdir -p "$_dir" || return
	fi
	chmod "$_perms" "$_dir"
}

# Prints the banner text provided by stdin to stderr.
#
# Examples:
#   show_banner "${color_green}${bold}" <<'EOF'
#   +-+-+-+-+-+ +-+-+-+-+-+-+
#   |H|e|l|l|o| |W|o|r|l|d|!|
#   +-+-+-+-+-+ +-+-+-+-+-+-+
#   EOF
#
# shellcheck disable=SC2120  # optional args
function show_banner() {
	if (($# < 1)); then
		log error "Usage: show_banner [color]"
		return 255
	fi
	local ansii_color_codes="$1"
	[[ -n $ansii_color_codes ]] && stderr -ne "$ansii_color_codes"
	setterm -linewrap off
	cat
	setterm -linewrap on
	[[ -n $ansii_color_codes ]] && stderr -ne "$color_reset"
}

# get the latest version string/tag name from a github repo
# source: https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
function _get_latest_github_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
		grep '"tag_name":' |                                             # Get tag line
		sed -E 's/.*"([^"]+)".*/\1/'                                     # Pluck JSON value
}

# factor; get the latest "vX.Y(.Z)" version of a GH project
function get_latest_github_release() {
	if [[ $# -ne 2 ]]; then
		log error "Expected two arguments: ghproject, outvar"
		return 255
	fi
	local ghproject="$1" outvar="$2" version
	log info -n "Looking up latest '$ghproject' version..."
	version="$(_get_latest_github_release "$ghproject")"
	if [[ ! "$version" =~ v[[:digit:]]+\.[[:digit:]]+(\.[[:digit:]]+)? ]]; then
		stderr "${color_red}failed${color_reset}."
		log error "malformed version string: \"$version\""
		return 1
	fi
	stderr "${theme_value}${version}${color_reset}"
	printf -v "$outvar" "%s" "$version"
}

# download a file silently (except on error) using `curl`
function download_file() {
	if [[ $# -ne 1 ]]; then
		log error "Usage: download_file url"
		return 255
	fi
	local url="$1"
	if ! curl -fLOSs "$url"; then
		log error "download failed: $url"
		return 1
	fi
}

# start-and-enable a system service
function enable_service() {
	if [[ $# -ne 1 ]]; then
		log error "Usage: enable_service unit_file"
		return 255
	fi
	local unit_file="$1"
	local service_name
	service_name="$(basename "$unit_file")"
	sudo systemctl start "$service_name"
	sudo systemctl enable "$service_name"
}

# stop-and-disable a system service
function disable_service() {
	if [[ $# -ne 1 ]]; then
		log error "Usage: disable_service unit_file"
		return 255
	fi
	local unit_file="$1"
	local service_name
	service_name="$(basename "$unit_file")"
	sudo systemctl stop "$service_name"
	sudo systemctl disable "$service_name"
}

# restart a system service
function restart_service() {
	if [[ $# -ne 1 ]]; then
		log error "Usage: restart_service unit_file"
		return 255
	fi
	local unit_file="$1"
	local service_name
	service_name="$(basename "$unit_file")"
	sudo systemctl restart "$service_name"
}

function enter_password_and_confirm() {
	if [[ $# -eq 4 ]]; then
		local prompt="$1" failmsg="$2" check_func="$3" outvar="$4"
	elif [[ $# -eq 2 ]]; then
		local prompt="$1" outvar="$2"
	else
		log error "Usage:\n\tenter_password_and_confirm prompt failmsg check_func outvar\n\tenter_password_and_confirm prompt outvar"
		return 255
	fi
	# loop until valid password
	while true; do
		IFS= read -rsp "$prompt: " password1
		stderr
		if [[ -z $check_func ]]; then
			break # no validator provided
		else
			reset_checks
			"$check_func" "password1"
			if has_failed_checks; then
				log warn "$failmsg"
				reset_checks
			else
				break # success
			fi
		fi
	done
	# loop until confirmed
	while true; do
		IFS= read -rsp "Re-enter to confirm: " password2
		stderr
		if [[ $password1 != "$password2" ]]; then
			log warn "confirmation failed, try again"
		else
			break # success
		fi
	done
	printf -v "$outvar" "%s" "$password1"
}

# source: https://stackoverflow.com/a/53839433/159570
function join_arr() {
	local IFS="$1"
	shift
	echo "$*"
}

# count the number of files in the given directory (or . if ommitted)
function number_of_files() {
	local dir=${1:-.}
	find "$dir" -maxdepth 1 -type f -printf "." | wc -c
}

# test expression for user existence
function user_exists() {
	id "$1" &>/dev/null
}

# test expression for group existence
function group_exists() {
	getent group "$1" &>/dev/null
}

# test expression for substring existence
function string_contains() {
	[[ "$1" == *"$2"* ]] &>/dev/null
}

# test expression for lack of network connectivity
#
# It is important to predicate upon the negative condition, so that errors are
# not mistaken for a confirmed lack of connection (e.g., for the use case of
# testing whether a system is air-gapped).
function has_no_network_connection() {
	local iface
	# iterate through all network interfaces except loopback
	for iface in /sys/class/net/*; do
		[[ "$(basename "$iface")" == "lo" ]] && continue

		# check if interface is up and has carrier (link detected)
		if [[ -f "$iface/carrier" && -f "$iface/operstate" ]]; then
			if [[ "$(<"$iface/carrier")" == "1" && "$(<"$iface/operstate")" == "up" ]]; then
				return 1
			fi
		fi
	done
	return 0
}

# factor
function _is_sourced() {
	if (($# == 0)); then
		log error "Usage: _is_sourced \"\${BASH_SOURCE[@]}\""
		return 255
	fi
	local -r shell_bin="$(readlink -f /proc/$$/exe)"
	local -r call_stack=("$@")

	# the first predicate is true when caller is sourced from shell script
	# the second predicate is true when caller is sourced from interactive shell
	[[ "${call_stack[0]}" != "${call_stack[-1]}" || "$0" == "$shell_bin" ]]
}

# test expression for whether caller's script was invoked with `source`
# example:
#   is_sourced "${BASH_SOURCE[@]}" && echo "This script was sourced."
function is_sourced() {
	# drop the current call stack frame from the analysis
	_is_sourced "${BASH_SOURCE[@]:1}"
}

# yes-or-no prompt
# 'no' is always falsey (returns 1)
function yes_or_no() {
	local confirm
	if [[ $# -ne 2 || ($1 != '--default-yes' && $1 != '--default-no') ]]; then
		log error 'Usage: yes_or_no {--default-yes|--default-no} prompt'
		return 255
	fi
	if [[ $1 == '--default-yes' ]]; then
		IFS= read -rp "$2 (Y/n): " confirm
		if [[ $confirm == [nN] || $confirm == [nN][oO] ]]; then
			return 1
		fi
	else
		IFS= read -rp "$2 (y/N): " confirm
		if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
			return 1
		fi
	fi
}

# "Continue?" prompt, defaulting to no, exiting on 'no' with given code or 1 by default
# shellcheck disable=SC2120  # optional args
function continue_or_exit() {
	local code=1 prompt="Continue?"
	if [[ $# -gt 0 ]]; then
		code=$1
	fi
	if [[ $# -gt 1 ]]; then
		prompt="$2"
	fi
	yes_or_no --default-no "$prompt" || exit "$code"
}

# pause script execution until user presses a key
function press_any_key_to_continue() {
	local -r prompt="${1:-Press any key to continue...}"
	IFS= read -rsn 1 -p $"$prompt"
	stderr "\n"
}

# pause script execution until user presses a key, then exit shell
function press_any_key_to_exit_shell() {
	press_any_key_to_continue 'Press any key to exit shell...'
}

# in-place shell selection list
# source: https://askubuntu.com/a/1386907
# changes: syntax cleanup, linting, cyclic selector
function choose_from_menu() {
	local -r prompt="$1" outvar="$2" options=("${@:3}")
	local -i cur=0 count=${#options[@]} index=0
	local esc
	esc=$(echo -en "\e") # cache ESC as test doesn't allow esc codes
	stderr "$prompt"
	while true; do
		# list all options (option list is zero-based)
		index=0
		for o in "${options[@]}"; do
			if ((index == cur)); then
				echo -e " >\e[7m$o\e[0m" # mark & highlight the current option
			else
				echo "  $o"
			fi
			index=$((index + 1))
		done
		IFS= read -rs -n3 key             # wait for user to key in arrows or ENTER
		if [[ $key == "${esc}[A" ]]; then # up arrow
			cur=$((cur - 1))
			((cur < 0)) && cur=$((count - 1))
		elif [[ $key == "${esc}[B" ]]; then # down arrow
			cur=$((cur + 1))
			((cur >= count)) && cur=0
		elif [[ $key == "" ]]; then # nothing, i.e the read delimiter - ENTER
			break
		fi
		echo -en "\e[${count}A" # go up to the beginning to re-render
	done
	# export the selection to the requested output variable
	printf -v "$outvar" "%s" "${options[$cur]}"
}

# -------------------------- ASSERTIONS ---------------------------------------

# assert sudoer status, and include hostname in prompt
# can prevent auth failures from polluting sudo'd conditional expressions
function assert_sudo() {
	if ! sudo -p '[sudo] password for %u@%H: ' true; then
		log error "failed to authenticate"
		exit 1
	fi
}

# assert that script process is running on given host
function assert_on_host() {
	if [[ $# -ne 1 ]]; then
		log error "Usage: assert_on_host <host>"
		exit 255
	fi
	local -r _hostname="$1"
	if [[ $(hostname) != "$1" ]]; then
		log error "script must be run on host '$_hostname'"
		exit 1
	fi
}

# assert that script process is not running on given host
function assert_not_on_host() {
	if [[ $# -ne 1 ]]; then
		log error "Usage: assert_not_on_host <host>"
		exit 2
	fi
	local -r _hostname="$1"
	if [[ $(hostname) == "$_hostname" ]]; then
		log error "script must not be run on host '$_hostname'"
		exit 1
	fi
}

# assert that script process does not have network access
function assert_offline() {
	if ! has_no_network_connection; then
		log error "script must be run on the air-gapped PC"
		exit 1
	fi
}

# assert that the caller's script was sourced, rather than executed directly
function assert_sourced() {
	# drop the current call stack frame from the analysis
	if ! _is_sourced "${BASH_SOURCE[@]:1}"; then
		log error "script must be sourced, not executed directly: ${theme_filename}${BASH_SOURCE[1]}${color_reset}"
		exit 1
	fi
}

# assert that the caller's script was executed directly, rather than sourced
function assert_not_sourced() {
	# drop the current call stack frame from the analysis
	if _is_sourced "${BASH_SOURCE[@]:1}"; then
		log error "script must be executed directly, not sourced: ${theme_filename}${BASH_SOURCE[1]}${color_reset}"
		# pause before closing interactive shell
		if [[ "$-" == *i* ]]; then
			press_any_key_to_exit_shell
		fi
		exit 1
	fi
}

# -------------------------- CHECKS -------------------------------------------

_check_failures=()

function reset_checks() {
	_check_failures=()
}

function has_failed_checks() {
	[[ ${#_check_failures[@]} -gt 0 ]]
}

# print failed checks with given log-level, return error code if failures
function print_failed_checks() {
	if [[ $# -ne 1 || ($1 != "--warn" && $1 != "--error") ]]; then
		log error "Usage: print_failed_checks {--warn|--error}"
		return 255
	fi
	local failcount=${#_check_failures[@]}
	local i
	if [[ $failcount -gt 0 ]]; then
		for ((i = 0; i < failcount; i++)); do
			if [[ $1 == "--warn" ]]; then
				log warn "${_check_failures[i]}"
			else
				log error "${_check_failures[i]}"
			fi
		done
		reset_checks
		return 1
	fi
}

function check_user_does_not_exist() {
	if _check_is_defined "$1"; then
		if user_exists "${!1}"; then
			_check_failures+=("user already exists: ${!1}")
		fi
	fi
}

function check_user_exists() {
	if _check_is_defined "$1"; then
		if ! user_exists "${!1}"; then
			_check_failures+=("user does not exist: ${!1}")
		fi
	fi
}

function check_group_does_not_exist() {
	if _check_is_defined "$1"; then
		if group_exists "${!1}"; then
			_check_failures+=("group already exists: ${!1}")
		fi
	fi
}

function check_group_exists() {
	if _check_is_defined "$1"; then
		if ! group_exists "${!1}"; then
			_check_failures+=("group does not exist: ${!1}")
		fi
	fi
}

function check_directory_does_not_exist() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined "$1"; then
		if $_sudo test -d "${!1}"; then
			_check_failures+=("directory already exists: ${!1}")
		fi
	fi
}

function check_directory_exists() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined "$1"; then
		if $_sudo test ! -d "${!1}"; then
			_check_failures+=("directory does not exist: ${!1}")
		fi
	fi
}

function check_file_does_not_exist() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined "$1"; then
		if $_sudo test -f "${!1}"; then
			_check_failures+=("file already exists: ${!1}")
		fi
	fi
}

function check_file_exists() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined "$1"; then
		if $_sudo test ! -f "${!1}"; then
			_check_failures+=("file does not exist: ${!1}")
		fi
	fi
}

function check_is_valid_port() {
	if _check_is_defined "$1"; then
		if [[ ${!1} -lt 1 || ${!1} -gt 65535 ]]; then
			_check_failures+=("invalid port: ${!1}")
		fi
	fi
}

function check_is_valid_ipv4_address() {
	# source: https://unix.stackexchange.com/a/111852
	local -r IPV4_OCTET='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
	local -r IPV4_REGEX="^$IPV4_OCTET\.$IPV4_OCTET\.$IPV4_OCTET\.$IPV4_OCTET\$"

	if _check_is_defined "$1"; then
		if [[ ! ${!1} =~ $IPV4_REGEX ]]; then
			_check_failures+=("invalid IPv4 address: ${!1}")
		fi
	fi
}

function check_command_does_not_exist_on_path() {
	if _check_is_defined "$1"; then
		if type -P "${!1}" &>/dev/null; then
			_check_failures+=("command already exists: ${!1}")
		fi
	fi
}

function check_command_exists_on_path() {
	if _check_is_defined "$1"; then
		if ! type -P "${!1}" &>/dev/null; then
			_check_failures+=("command does not exist: ${!1}")
		fi
	fi
}

function check_executable_does_not_exist() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined "$1"; then
		if $_sudo test -x "${!1}"; then
			_check_failures+=("executable already exists: ${!1}")
		fi
	fi
}

function check_executable_exists() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined "$1"; then
		if $_sudo test ! -x "${!1}"; then
			_check_failures+=("file does not exist or is not executable: ${!1}")
		fi
	fi
}

function check_is_service_installed() {
	local service_name
	if _check_is_defined "$1"; then
		service_name="$(basename "${!1}")"
		if ! systemctl list-unit-files --full -all | grep -Fq "$service_name"; then
			_check_failures+=("service is not installed: ${!1}")
		fi
	fi
}

function check_is_service_active() {
	local service_name
	if _check_is_defined "$1"; then
		service_name="$(basename "${!1}")"
		if ! systemctl is-active --quiet "$service_name"; then
			_check_failures+=("service is not active: $service_name")
		fi
	fi
}

function check_string_contains() {
	if _check_is_defined "$1"; then
		if ! string_contains "${!1}" "$2"; then
			_check_failures+=("$1 does not contain \"$2\"")
		fi
	fi
}

function check_current_directory_is() {
	local resolved_dir
	if _check_is_defined "$1"; then
		resolved_dir="$(realpath "${!1}")"
		if [[ $(pwd) != "$resolved_dir" ]]; then
			_check_failures+=("current directory is not $resolved_dir")
		fi
	fi
}

function check_current_directory_is_not() {
	local resolved_dir
	if _check_is_defined "$1"; then
		resolved_dir="$(realpath "${!1}")"
		if [[ $(pwd) == "$resolved_dir" ]]; then
			_check_failures+=("current directory is $resolved_dir")
		fi
	fi
}

function check_is_positive_integer() {
	if _check_is_defined "$1"; then
		if [[ ! ${!1} =~ ^[[:digit:]]+$ || ! ${!1} -gt 0 ]]; then
			_check_failures+=("$1: expected a positive integer")
		fi
	fi
}

function check_is_boolean() {
	if _check_is_defined "$1"; then
		if [[ (${!1} != 'true' && ${!1} != 'false') ]]; then
			_check_failures+=("$1: expected a boolean value")
		fi
	fi
}

# predicate (may return non-zero)
function _check_is_defined() {
	if [[ $# -ne 1 ]]; then
		log error "No argument provided"
		return 255
	fi
	if [[ -z ${!1} ]]; then
		_check_failures+=("variable is undefined: $1")
		return 1
	fi
}

# non-predicate (avoids triggering errexit)
function check_is_defined() {
	_check_is_defined "$1" || true
}

function check_argument_not_missing() {
	if [[ $# -ne 1 ]]; then
		log error "No argument name provided"
		return 255
	fi
	if [[ -z ${!1} ]]; then
		_check_failures+=("missing argument: $1")
	fi
}

# -------------------------- FOOTER -------------------------------------------

# this script should be sourced rather than executed directly
assert_sourced
