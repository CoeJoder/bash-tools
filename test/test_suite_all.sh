#!/bin/bash

# test_suite_all.sh
#
# Runs all `bash-tools` tests defined in `tests.sh`

this_dir="$(dirname "$(realpath "$0")")"
export this_dir

function test_in_subshell() ( # subshell
	source "$this_dir/tests.sh"
	run_test "$1"
)

# test state isolation enforced by one-test-per-subshell
test_in_subshell test_log
test_in_subshell test_yes_or_no
test_in_subshell test_continue_or_exit
test_in_subshell test_check_directory_does_not_exist
test_in_subshell test_check_directory_exists
test_in_subshell test_check_file_does_not_exist
test_in_subshell test_check_file_exists
test_in_subshell test_check_executable_does_not_exist
test_in_subshell test_check_executable_exists
test_in_subshell test_check_is_valid_ipv4_address
test_in_subshell test_is_sourced
