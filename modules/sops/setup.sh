#!/usr/bin/env bash

# age_key_file is dynamic to the system, which we evaluate more easily in nix

key_name="$USER"
ssh_key_file="$HOME/.ssh/$key_name"
sops_repo_file="$(git rev-parse --show-toplevel)/.canivete/sops/$key_name"
# shellcheck disable=SC2154
mkdir -p "$(dirname "$age_key_file")"

# Generate a passwordless SSH key
ssh-keygen -t ed25519 -P "" -f "$ssh_key_file" &> /dev/null

# Create private and public age key from SSH key
ssh-to-age -private-key -i "$ssh_key_file" > "$age_key_file" 2> /dev/null
age_key_public="$(age-keygen -y "$age_key_file")"

# Prompt user
logfx -<<EOT
    Your public age key is $age_key_public

    Ensure the following in .sops.yaml before running 'nix run .#encrypt':

    keys:
      - &$key_name $age_key_public
    creation_rules:
      - path_regex: $sops_repo_file$
        key_groups:
          - age:
              - *$key_name
EOT
