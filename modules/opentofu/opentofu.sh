#!/usr/bin/env -S usage bash
set -eo pipefail

# USAGE arg "<args>" var=#true
# USAGE flag "-w --workspace <workspace>" env="DOTSHIP_OPENTOFU_WORKSPACE"

# shellcheck disable=SC2154
opentofu_args="$usage_args"
# shellcheck disable=SC2154
opentofu_workspace="$usage_workspace"

git_dir="$(git rev-parse --show-toplevel)"
system="$(nix eval --raw --import --expr "builtins.currentSystem")"
opentofu_workspaces_path="$git_dir#dotship.$system.opentofu.workspaces"

declare -A valid_opentofu_workspaces
readarry -t valid_opentofu_workspaces < <(nix eval --json --apply builtins.attrNames "$opentofu_workspaces_path" | jq --raw-output ".[]")

function parse-args {
  [[ -z $opentofu_workspace ]] && opentofu_workspace="$(gum choose "${valid_opentofu_workspaces[@]}")"

  if ! dotship has-duplicates "$opentofu_workspace" "${valid_opentofu_workspaces[@]}"; then
    gum log --level error "No valid workspace selected. Options are: ${valid_opentofu_workspaces[*]}"
    exit 1
  fi
}

function main {
  run_dir="$git_dir/.dotship/opentofu/$opentofu_workspace"
  dec_file="$run_dir/config.tf.json"
  opentofu_workspace_path="$opentofu_workspaces_path.$opentofu_workspace"

  opentofu_command=("nix" "run" "$opentofu_workspace_path.package" -- -chdir="$run_dir")

  mkdir -p "$run_dir"
  trap 'rm -rf "$run_dir/.terraform" "$run_dir/.terraform.lock.hcl" "$dec_file"' EXIT

  nix build "$opentofu_workspace_path.json" --no-link --print-out-paths |
    xargs cat |
    vals eval -s -f - |
    yq "." >"$dec_file"

  export TF_VAR_GIT_DIR="$git_dir"
  "${opentofu_command[@]}" init -upgrade
  "${opentofu_command[@]}" "$opentofu_args"
}

parse-args
main
