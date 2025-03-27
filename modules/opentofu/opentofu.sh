#!/usr/bin/env bash

usage="Usage: $0 [-w|--workspace WORKSPACE] [-h|--help] <opentofu args>"
git_dir="$(git rev-parse --show-toplevel)"
system="$(nix eval --raw --impure --expr "builtins.currentSystem")"
workspaces_path="$git_dir#canivete.$system.opentofu.workspaces"
readarray -t workspaces < <(nix eval --json --apply builtins.attrNames "$workspaces_path" | jq --raw-output ".[]")

WORKSPACE="${CANIVETE_OPENTOFU_WORKSPACE-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
    -w | --workspace)
        WORKSPACE="$2"
        shift
        ;;
    -h | --help)
        echo "$usage"
        exit
        ;;
    *)
        break
        ;;
    esac
    shift
done
WORKSPACE="${WORKSPACE:-\"$(gum choose "${workspaces[@]}")\"}"
if ! canivete has_duplicates "$WORKSPACE" "${workspaces[@]}"; then
    gum log --level error "No valid workspace selected. Options are: ${workspaces[*]}"
    exit 1
fi

run_dir="$git_dir/.canivete/opentofu/$WORKSPACE"
dec_file="$run_dir/config.tf.json"
workspace_path="$workspaces_path.$WORKSPACE"
tofu=("nix" "run" "$workspace_path.package" -- -chdir="$run_dir")

mkdir -p "$run_dir"
trap 'rm -rf "$run_dir/.terraform" "$run_dir/.terraform.lock.hcl" "$dec_file"' EXIT
nix build "$workspace_path.json" --no-link --print-out-paths |
    xargs cat |
    vals eval -s -f - |
    yq "." >"$dec_file"
"${tofu[@]}" init -upgrade
"${tofu[@]}" "$@"
