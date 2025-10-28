#!/bin/bash

# tests.sh
#
# Defines unit and integration tests for `bash-tools`.

# -------------------------- HEADER -------------------------------------------

this_dir="$(dirname "$(realpath "$0")")"
bash_tools_sh="$this_dir/../src/bash-tools.sh"

# shellcheck source=./../src/bash-tools.sh
source "$bash_tools_sh"

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null || exit

function on_exit() {
	printinfo -n "Cleaning up ${color_lightgray}[$temp_dir]${color_reset}..."
	popd >/dev/null || return
	[[ -d $temp_dir ]] && sudo rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_exit' EXIT

# -------------------------- TEST FIXTURES ------------------------------------

failures=()

function reset_test_failures() {
	failures=()
}

function print_test_results() {
	local failcount=${#failures[@]}
	local i
	if [[ $failcount -eq 0 ]]; then
		echo "${color_green}passed${color_reset}"
		reset_test_failures
		return 0
	fi
	echo "${color_red}failed ($failcount)${color_reset}:"
	for ((i = 0; i < failcount; i++)); do
		echo "  ${failures[i]}"
	done
	reset_test_failures
}

function run_test() {
	printinfo -n "Running: ${color_yellow}$1${color_reset}..."
	"$1"
	print_test_results
}

#
# these functions adapt the `check_` functions to the test fixtures:
#

function _dont_expect_checkfailures() {
	if [[ ${#_check_failures[@]} -gt 0 ]]; then
		failures+=("${_check_failures[@]}")
	fi
}

function _expect_checkfailures() {
	local expected_count=$1
	local actual_count=${#_check_failures[@]}
	if [[ $expected_count -ne $actual_count ]]; then
		failures+=("line $(caller): check-failures expected: ${expected_count}, actual: ${color_red}$actual_count${color_reset}")
	fi
}

# -------------------------- TEST CASES ---------------------------------------

function test_log() {
	local teststr="test string"
	local msglevel
	local loglevel
	local logoutput
	local i

	local should_not_print=(
		# msglevel,loglevel
		'trace,debug'

		'trace,info'
		'debug,info'

		'trace,warn'
		'debug,warn'
		'info,warn'

		'trace,error'
		'debug,error'
		'info,error'
		'warn,error'

		'trace,fatal'
		'debug,fatal'
		'info,fatal'
		'warn,fatal'
		'error,fatal'
	)

	local should_print=(
		# msglevel,loglevel
		'trace,trace'
		'debug,trace'
		'info,trace'
		'warn,trace'
		'error,trace'
		'fatal,trace'
		
		'debug,debug'
		'info,debug'
		'warn,debug'
		'error,debug'
		'fatal,debug'
		
		'info,info'
		'warn,info'
		'error,info'
		'fatal,info'
		
		'warn,warn'
		'error,warn'
		'fatal,warn'
		
		'error,error'
		'fatal,error'
		
		'fatal,fatal'
	)

	# case 1: should not print
	for ((i = 0; i < ${#should_not_print[@]}; i++)); do
		IFS=',' read -r msglevel loglevel <<<"${should_not_print[i]}"
		set_loglevel "$loglevel"
		logoutput="$(log "$msglevel" "$teststr" 2>&1)"
		if [[ -n "$logoutput" ]]; then
			failures+=("'$msglevel' message should not print at log-level '$loglevel'")
		fi	
	done

	# case 2: should print
	for ((i = 0; i < ${#should_print[@]}; i++)); do
		IFS=',' read -r msglevel loglevel <<<"${should_print[i]}"
		set_loglevel "$loglevel"
		logoutput="$(log "$msglevel" "$teststr" 2>&1)"
		if [[ -z "$logoutput" ]]; then
			failures+=("'$msglevel' message should print at log-level '$loglevel'")
		elif [[ "${logoutput#* }" != "$teststr" ]]; then  # test chars after 1st space
			failures+=("expected: '$teststr', actual: '$logoutput'")
		fi
	done
}

# tests for `yes_or_no()` in common.sh
function test_yes_or_no() {
	#
	# --default-yes
	#
	if echo "y" | yes_or_no "--default-yes" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (y)(--default-yes)")
	fi
	if echo "n" | yes_or_no "--default-yes" "Continue?"; then
		failures+=("Expected 'no' (n)(--default-yes)")
	else
		: # success
	fi
	if echo "" | yes_or_no "--default-yes" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (<blank>)(--default-yes)")
	fi
	if echo "zebra" | yes_or_no "--default-yes" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (zebra)(--default-yes)")
	fi

	#
	# --default-no
	#
	if echo "y" | yes_or_no "--default-no" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (y)(--default-no)")
	fi
	if echo "n" | yes_or_no "--default-no" "Continue?"; then
		failures+=("Expected 'no' (n)(--default-no)")
	else
		: # success
	fi
	if echo "" | yes_or_no "--default-no" "Continue?"; then
		failures+=("Expected 'no' (<blank>)(--default-no)")
	else
		: # success
	fi
	if echo "zebra" | yes_or_no "--default-no" "Continue?"; then
		failures+=("Expected 'no' (zebra)(--default-no)")
	else
		: # success
	fi
}

# tests for `continue_or_exit()` in common.sh
function test_continue_or_exit() {
	local yeses=(
		'y'
		'yes'
	)
	local nos=(
		'n'
		'no'
		''
		'zebra'
	)
	local curtest i

	for ((i = 0; i < ${#yeses[@]}; i++)); do
		curtest=${yeses[i]}
		if ! echo "$curtest" | continue_or_exit 3; then
			failures+=("Expected 'yes' (${curtest:-"<blank>"})")
		fi
	done

	for ((i = 0; i < ${#nos[@]}; i++)); do
		curtest=${nos[i]}
		echo "$curtest" | continue_or_exit 3
		if [[ $? -ne 3 ]]; then
			failures+=("Expected 'no' (${curtest:-"<blank>"})")
		fi
	done
}

# test for check_directory_does_not_exist() in common.sh
function test_check_directory_does_not_exist() {
	local exists_arr=(
		'./tempdir1/'
		'./tempdir2/zebra'
	)
	local exists_root_arr=(
		'./tempdir3/'
		'./tempdir4/zebra'
	)
	local not_exist_arr=(
		'./tempdir5/'
		'./tempdir6/zebra'
	)
	local not_exist_root_arr=(
		'./tempdir7/'
		'./tempdir8/zebra'
	)
	local curtest i len

	# exists
	reset_checks
	len=${#exists_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_arr[i]}"
		mkdir -p "$curtest"
		check_directory_does_not_exist curtest
	done
	_expect_checkfailures "$len"

	# exists, owned by root
	reset_checks
	len=${#exists_root_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_root_arr[i]}"
		sudo mkdir -p "$curtest"
		check_directory_does_not_exist --sudo curtest
	done
	_expect_checkfailures "$len"

	# not exist
	reset_checks
	len=${#not_exist_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${not_exist_arr[i]}"
		check_directory_does_not_exist curtest
	done
	_dont_expect_checkfailures

	# not exist, owned by root
	reset_checks
	for ((i = 0; i < ${#not_exist_root_arr[@]}; i++)); do
		curtest="${not_exist_root_arr[i]}"
		check_directory_does_not_exist --sudo curtest
	done
	_dont_expect_checkfailures
}

# test for check_directory_exists() in common.sh
function test_check_directory_exists() {
	local exists_arr=(
		'./tempdir1/'
		'./tempdir2/zebra'
	)
	local exists_root_arr=(
		'./tempdir3/'
		'./tempdir4/zebra'
	)
	local not_exist_arr=(
		'./tempdir5/'
		'./tempdir6/zebra'
	)
	local not_exist_root_arr=(
		'./tempdir7/'
		'./tempdir8/zebra'
	)
	local curtest i len

	# exists
	reset_checks
	len=${#exists_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_arr[i]}"
		mkdir -p "$curtest"
		check_directory_exists curtest
	done
	_dont_expect_checkfailures

	# exists, owned by root
	reset_checks
	len=${#exists_root_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_root_arr[i]}"
		sudo mkdir -p "$curtest"
		check_directory_exists --sudo curtest
	done
	_dont_expect_checkfailures

	# not exist
	reset_checks
	len=${#not_exist_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${not_exist_arr[i]}"
		check_directory_exists curtest
	done
	_expect_checkfailures "$len"

	# not exist, owned by root
	reset_checks
	len=${#not_exist_root_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${not_exist_root_arr[i]}"
		check_directory_exists --sudo curtest
	done
	_expect_checkfailures "$len"
}

# test for check_file_does_not_exist() in common.sh
function test_check_file_does_not_exist() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	check_file_does_not_exist curtest
	_expect_checkfailures 1

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	check_file_does_not_exist --sudo curtest
	_expect_checkfailures 1

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_file_does_not_exist curtest
	_dont_expect_checkfailures

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_file_does_not_exist --sudo curtest
	_dont_expect_checkfailures
}

# test for check_file_exists() in common.sh
function test_check_file_exists() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	check_file_exists curtest
	_dont_expect_checkfailures

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	check_file_exists --sudo curtest
	_dont_expect_checkfailures

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_file_exists curtest
	_expect_checkfailures 1

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_file_exists --sudo curtest
	_expect_checkfailures 1
}

# test for check_executable_does_not_exist() in common.sh
function test_check_executable_does_not_exist() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	chmod +x "$curtest"
	check_executable_does_not_exist curtest
	_expect_checkfailures 1

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	sudo chmod +x "$curtest"
	check_executable_does_not_exist --sudo curtest
	_expect_checkfailures 1

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_executable_does_not_exist curtest
	_dont_expect_checkfailures

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_executable_does_not_exist --sudo curtest
	_dont_expect_checkfailures
}

# test for check_executable_exists() in common.sh
function test_check_executable_exists() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	chmod +x "$curtest"
	check_executable_exists curtest
	_dont_expect_checkfailures

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	sudo chmod +x "$curtest"
	check_executable_exists --sudo curtest
	_dont_expect_checkfailures

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_executable_exists curtest
	_expect_checkfailures 1

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_executable_exists --sudo curtest
	_expect_checkfailures 1
}

function test_check_is_valid_ipv4_address() {
	local valid=(
		'192.168.1.50'
		'255.255.255.0'
		'10.10.0.42'
	)
	local invalid=(
		'2600:8801:9a00:c:8aff:8ec2:f651'
		'256.1.1.1'
		'google.com'
	)
	local i curtest len

	# valid
	reset_checks
	len=${#valid[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${valid[i]}"
		check_is_valid_ipv4_address curtest
	done
	_dont_expect_checkfailures

	# invalid
	reset_checks
	len=${#invalid[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${invalid[i]}"
		check_is_valid_ipv4_address curtest
	done
	_expect_checkfailures "$len"
}

function test_is_sourced() {
	local actual_output_of_sourcing
	local actual_output_of_direct_execution
	local expected_output_of_sourcing
	local expected_output_of_direct_execution
	local shell_bin

	local -r script_A="$(mktemp --tmpdir="$temp_dir")"
	local -r script_B="$(mktemp --tmpdir="$temp_dir")"
	chmod +x "$script_A"
	chmod +x "$script_B"

	cat <<-EOF > "$script_A"
	#!/bin/bash
	source "$bash_tools_sh"

	echo -n "  [script_A] Am I sourced?"
	if is_sourced; then
		echo " Yes."
	else
		echo " No."
	fi
	EOF

	cat <<-EOF > "$script_B"
	#!/bin/bash
	echo "Sourcing script_A..."
	source "$script_A"

	echo -n "  [script_B] Am I sourced?"
	if is_sourced; then
		echo " Yes."
	else
		echo " No."
	fi

	echo "Executing script_A..."
	"$script_A"
	EOF

	# Need to test two cases:
	# 1. non-interactive shell (i.e., `is_sourced` is called from a shell script)
	# 2. interactive shell (i.e., `is_sourced` is called from a terminal shell)

	## First pair of tests (non-interactive shell)

	# actual output of `source $script_B`
	# shellcheck disable=SC1090
	actual_output_of_sourcing="$(source "$script_B")"
	
	# actual output of directly executing `$script_B`
	# shellcheck disable=SC1090
	actual_output_of_direct_execution="$("$script_B")"

	# expected output of sourcing script_B
	expected_output_of_sourcing=$(cat <<-EOF
	Sourcing script_A...
	  [script_A] Am I sourced? Yes.
	  [script_B] Am I sourced? Yes.
	Executing script_A...
	  [script_A] Am I sourced? No.
	EOF
	)

	# expected output of directly executing script_B
	expected_output_of_direct_execution=$(cat <<-EOF
	Sourcing script_A...
	  [script_A] Am I sourced? Yes.
	  [script_B] Am I sourced? No.
	Executing script_A...
	  [script_A] Am I sourced? No.
	EOF
	)

	function compare_expected_actual() {
		local -r test_label="$1"
		local failure

		if [[ "$actual_output_of_sourcing" != "$expected_output_of_sourcing" ]]; then
			failure=$(cat <<-EOF
			
			## Test case: "$test_label"

			# Actual output of \`source script_B.sh:\`
			$actual_output_of_sourcing

			# Expected output of \`source script_B.sh:\`
			$expected_output_of_sourcing

			EOF
			)
			failures+=("$failure")
		fi

		if [[ "$actual_output_of_direct_execution" != "$expected_output_of_direct_execution" ]]; then
			failure=$(cat <<-EOF

			## Test case: "$test_label"

			# Actual output of \`script_B.sh:\`
			$actual_output_of_direct_execution

			# Expected output of \`script_B.sh:\`
			$expected_output_of_direct_execution

			EOF
			)
			failures+=("$failure")
		fi
	}

	compare_expected_actual "non-interactive shell"

	## Second pair of tests (interactive shell)

	# invoking this way, $0 is set to the canonical path of the shell binary, 
	# e.g., /usr/bin/bash, but only when sourcing the script, not when executed 
	# directly (as is the case with interactive shells)

	shell_bin="$(readlink -f /proc/$$/exe)"
	actual_output_of_sourcing="$("$shell_bin" -c "source '$script_B'")"
	actual_output_of_direct_execution="$("$shell_bin" -c "$script_B")"

	compare_expected_actual "interactive shell"
}

