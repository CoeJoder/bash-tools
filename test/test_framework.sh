#!/bin/bash
#
# test_framework.sh
# Can be sourced by test scripts to provide basic test fixtures.

# -------------------------- TEST FIXTURES ------------------------------------

# shellcheck disable=SC2154  # colors and 'check_' vars initialized by caller

# setup a per-test temp directory to be deleted on EXIT
BASHTOOLS_TEST_TEMP_DIR=$(mktemp -d)
pushd "$BASHTOOLS_TEST_TEMP_DIR" >/dev/null || exit

function on_exit() {
	printinfo -n "Cleaning up $BASHTOOLS_TEST_TEMP_DIR..."
	popd >/dev/null || return
	# TODO avoid `sudo rm` by allowing subshells to communicate with test runner
	# as to which directories require `sudo rm` after-all tests complete.
	[[ -d $BASHTOOLS_TEST_TEMP_DIR ]] && \
		sudo rm -rf --interactive=never "$BASHTOOLS_TEST_TEMP_DIR" >/dev/null
	print_ok
}

trap 'on_exit' EXIT

# setup test result aggregation and reporting
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
