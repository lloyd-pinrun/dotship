#!/usr/bin/env bash

key_name="$USER"
ssh_key_file="$HOME/.ssh/$key_name"
sops_repo_file="$(git rev-parse --show-toplevel)/.canivete/sops/$key_name"

# Prompt user
logfx <<<"Ensure you have already created an SSH key and .sops.yaml file in the repo by running 'nix run .#setup'"

# Copy SSH keys into repo and encrypt
cp "$ssh_key_file" "$sops_repo_file"
cp "$ssh_key_file.pub" "$sops_repo_file.pub"
sops --encrypt --in-place "$sops_repo_file"
