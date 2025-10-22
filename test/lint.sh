#!/bin/bash

# lint.sh
#
# Runs `shellcheck` on all of the bash scripts in the given directories and
# their subdirectories.
#
# Example:
# ../bash-tools/test/lint.sh \
#   --path ./src
#   --path ./test
#   --path ./tools

set -eo pipefail

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/../src/bash-tools.sh"

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename "${BASH_SOURCE[0]}") [options]
		Options:
		--shellcheck-min-ver ${underline}ver${nounderline}   The minimum required version of the system's shellcheck (default: 0.9.0)
		--path ${underline}path${nounderline}                A root paths containing bash scripts.  Multiple supported.  Omit to lint \`bash-tools\` itself.
		--help, -h                 Show this message
	EOF
}

_parsed_args=$(getopt \
	--options='h' \
	--longoptions='help,shellcheck-min-ver:,path:' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

shellcheck_min_ver='0.9.0'
paths=()

while true; do
	case "$1" in
	--shellcheck-min-ver)
		shellcheck_min_ver="$2"
		shift 2
		;;
	--path)
		paths+=("$2")
		shift 2
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

shellcheck_version_regex='version: ([[:digit:]]\.[[:digit:]]\.[[:digit:]])'

# assert shellcheck is installed
if ! type -P 'shellcheck' &>/dev/null; then
	echo "shellcheck not found on path; install it and relaunch" >&2
	exit 1
fi

# assert shellcheck meets the minimum version requirement
while IFS= read -r line; do
	if [[ "$line" =~ $shellcheck_version_regex ]]; then
		version="${BASH_REMATCH[1]}"
	fi
done < <(shellcheck --version)

if [[ -z "$version" ]]; then
	echo "failed to parse the version string from \`shellcheck --version\`" >&2
	exit 1
fi

if [[ "$shellcheck_min_ver" != "$version" ]]; then
	if [[ "$(printf '%s\n' "$shellcheck_min_ver" "$version" | sort -rV | head -n1)" == "$shellcheck_min_ver" ]]; then
		echo "installed version of shellcheck ($version) does not meet the minumum requirement ($shellcheck_min_ver); upgrade it and relaunch" >&2
		exit 1
	fi
fi

# source: https://github.com/koalaman/shellcheck/issues/143#issuecomment-909009632
function is_bash() {
	local file="$1"
	[[ "$file" == *.sh ]] && return 0
	[[ "$file" == */bash-completion/* ]] && return 0
	[[ "$(file -b --mime-type "$file")" == 'text/x-shellscript' ]] && return 0
	return 1
}

# source: https://github.com/koalaman/shellcheck/issues/143#issuecomment-909009632
function recursive_bash_lint() {
	local script_dir="$1"
	while IFS= read -r -d $'' file; do
		if is_bash "$file"; then
			shellcheck -s bash "$file" || continue
		fi
	done < <(find "$script_dir" -type f -print0 \
		! -path './.git/*' \
		! -path './.node_modules/*')
}

# lint all bash scripts within paths passed as script args
# or if no paths supplied, lint `bash-tools` itself
if (( ${#paths[@]} > 0 )); then
	for path in "${paths[@]}"; do
		recursive_bash_lint "$path"
	done
else
	proj_dir="$(realpath "$this_dir/..")"
	recursive_bash_lint "$proj_dir/src"
	recursive_bash_lint "$proj_dir/test"
fi
