#!/usr/bin/env bash
set -eo pipefail

# shellcheck disable=SC2155 # No way to assign to readonly variable in separate lines
readonly SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

function main {
  common::initialize "$SCRIPT_DIR"
  parse_cmdline_ "$@"
  nomad_validate_
}

#######################################################################
# Parse args and filenames passed to script and populate respective
# global variables with appropriate values
# Globals (init and populate):
#   ARGS (array) arguments that configure wrapped tool behavior
#   ENVS (array) environment variables that will be used with
#     `nomad` commands
#   FILES (array) filenames to check
# Arguments:
#   $@ (array) all specified in `hooks.[].args` in
#     `.pre-commit-config.yaml` and filenames.
#######################################################################
function parse_cmdline_ {
  declare argv
  argv=$(getopt -o e:i:a: --long envs:,init-args:,args: -- "$@") || return
  eval "set -- $argv"

  for argv; do
    case $argv in
      -a | --args)
        shift
        ARGS+=("$1")
        shift
        ;;
      -e | --envs)
        shift
        ENVS+=("$1")
        shift
        ;;
      --)
        shift
        FILES=("$@")
        break
        ;;
    esac
  done
}

#######################################################################
# Wrapper around `nomad validate` tool that checks if code is valid
# 1. Export provided env var K/V pairs to environment
# 2. Because hook runs on whole dir, reduce file paths to uniq dir paths
# 3. In each dir that have *.nomad files:
# 3.2. Run `nomad validate`
# 3.3. If at least 1 check failed - change exit code to non-zero
# 4. Complete hook execution and return exit code
# Globals:
#   ARGS (array) arguments that configure wrapped tool behavior
#   ENVS (array) environment variables that will be used with
#     `nomad` commands
#   FILES (array) filenames to check
# Outputs:
#   If failed - print out hook checks status
#######################################################################
function nomad_validate_ {

  # Setup environment variables
  local var var_name var_value
  for var in "${ENVS[@]}"; do
    var_name="${var%%=*}"
    var_value="${var#*=}"
    # shellcheck disable=SC2086
    export $var_name="$var_value"
  done

  declare -a paths
  local index=0
  local error=0

  local file_with_path
  for file_with_path in "${FILES[@]}"; do
    file_with_path="${file_with_path// /__REPLACED__SPACE__}"

    paths[index]=$(dirname "$file_with_path")
    ((index += 1))
  done

  local dir_path
  for dir_path in $(echo "${paths[*]}" | tr ' ' '\n' | sort -u); do
    dir_path="${dir_path//__REPLACED__SPACE__/ }"

    if [[ -n "$(find "$dir_path" -maxdepth 1 -name '*.nomad' -print -quit)" ]]; then
      pushd "$(realpath "$dir_path")" > /dev/null
      set +e
      validate_output=$(nomad validate "${ARGS[@]}" 2>&1)
      validate_code=$?
      set -e

      if [ $validate_code -ne 0 ]; then
        error=1
        echo "Validation failed: $dir_path"
        echo "$validate_output"
        echo
      fi

      popd > /dev/null
    fi
  done

  if [ $error -ne 0 ]; then
    exit 1
  fi
}

# global arrays
declare -a ENVS

[ "${BASH_SOURCE[0]}" != "$0" ] || main "$@"