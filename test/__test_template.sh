#!/bin/bash

# __test_template.sh
#
# Test script template and demo for the `bash-tools` test framework.

# -------------------------- HEADER -------------------------------------------

trap 'on_err' ERR

# this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

########## import script under test
# source "$this_dir/../src/my-script.sh"

########## import `bash-tools` test framework
# source "$this_dir/../external/bash-tools/test/test_framework.sh"

# -------------------------- TEST CASES ---------------------------------------

# More examples: `bash-tools/test/tests.sh`

function test_foo() {
	if foo; then
		failures+=("foo() failed")
	fi
}

function test_bar() {
	if bar; then
		failures+=("bar() failed")
	fi
}

# -------------------------- TEST RUNNER --------------------------------------

run_test test_foo
run_test test_bar
