#!/usr/bin/env bash

declare usage
usage="Usage: $0 [-w|--workspace WORKSPACE] [-h|--help] <opentofu args>"

declare git_dir
declare system
declare tofu_args
declare workspaces

git_dir="$(git rev-parse --show-toplevel)"
system="$(nix eval --raw --impure --expr "builtins.currentSystem")"

WORKSPACE="${DOTSHIP_OPENTOFU_WORKSPACE-}"

function generate-workspaces {
  local workspace
  workspace=$(nix eval --json --apply builtins.attrNames "$workspaces_path" | jq --raw-output ".[]")

  while read -r workspace; do
    workspaces+=("$workspace")
  done
}

function validate-workspace {
  local workspace "$1"

  local -A workspaces_map
  for workspace in "${!workspaces[@]}"; do workspaces_map[${workspaces[$workspace]}]="$workspace"; done

  if [[ -n ${workspaces_map[$workspace]} ]]; then
    WORKSPACE="$workspace"
  else
    gum --level error "Not valid workspace selected. Options are: ${workspaces[*]}"
    exit 1
  fi
}

function parse-flags {
  local workspace

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -w | --workspace)
      workspace="$2"
      shift
      ;;
    --)
      tofu_args="$2"
      shift
      ;;
    -h | --help)
      echo "$usage"
      exit 0
      ;;
    *) break ;;
    esac

    shift
  done

  if [[ -n ${workspace+x} ]]; then validate-workspace "$workspace"; fi
}

function main {
  local dec_file
  local run_dir
  local tofu
  local workspace
  local workspaces_path

  workspaces_path="$git_dir#dotship.$system.opentofu.workspaces"

  generate-workspaces

  if [[ $# -eq 0 ]]; then
    workspace="$(gum choose "${workspaces[@]}" --header "Choose workspace:")"
  else
    parse-flags "$@"
    workspace="$WORKSPACE"
  fi

  run_dir="$git_dir/.dotship/opentofu/$workspace"
  dec_file="$run_dir/config.tf.json"
  workspaces_path="$workspaces_path.$workspace"
  tofu=("nix" "run" "$workspaces_path.package" -- -chdir="run_dir")

  mkdir -p "$run_dir"
  trap 'rm -rf "$run_dir/.terraform" "$run_dir/.terraform.lock.hcl" "$dec_file"' EXIT

  nix build "$workspaces_path" --no-link --print-out-paths |
    xargs cat |
    vals eval -s -f - |
    yq "." >"$dec_file"

  export TF_VAR_GIT_DIR="$git_dir"

  "${tofu[@]}" init -upgrade
  "${tofu[@]}" "$tofu_args"
}

main "$@"
