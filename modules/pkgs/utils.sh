#!/usr/bin/env -S usage bash
set -eo pipefail

#USAGE cmd "contains" help="Checks if an array contains the specified entry" {
#USAGE   arg "<array>"
#USAGE   arg "<entry>"
#USAGE }
#USAGE cmd "has-duplicates" help="Checks if an array includes duplicate entries" {
#USAGE   arg "<array>"
#USAGE }

function get-duplicates {
  [[ -z $usage_array ]] && gum log --level error "get-duplicates requires you to pass an existing array" && exit 2

  # shellcheck disable=SC2154
  local -n array="$usage_array"

  printf '%s\0' "${array[@]}" | sort --zero-terminated | uniq --zero-terminated --repeated
}

function has-duplicates {
  [[ -z $usage_array ]] && gum log --level error "has-duplicates requires you to pass an existing array" && exit 2

  local -n array="$usage_array"
  local duplicates
  readarray -td '' duplicates < <(get-duplicates "$array")

  if ((${#duplicates[@]} > 0)); then
    return 0
  else
    return 1
  fi
}

function contains {
  [[ -z $usage_array ]] && gum log --level "contains requires you to pass an existing array" && exit 2
  [[ -z $usage_entry ]] && gum log --level "contains requires you to pass an entry" && exit 2

  # shellcheck disable=SC2154
  local -n array="$usage_array"
  # shellcheck disable=SC2154
  local entry="$usage_entry"

  contains_array=("$entry" "${array[@]}")
  has-duplicates "${contains_array[@]}"
}
