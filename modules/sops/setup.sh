#!/usr/bin/env -S usage bash
set -eo pipefail

#USAGE flag "-n --name <ssh-key-name>" env="DOTSHIP_SOPS_SSH_KEY_NAME"
#USAGE flag "-f --file <age-key-file>" env="DOTSHIP_SOPS_AGE_KEY_FILE"

# shellcheck disable=SC2154
ssh_key_name="${usage_name:-sops}"
# shellcheck disable=SC2154
age_key_file="$usage_file"

function parse-args {
  [[ -z $ssh_key_name ]] && gum log --level error "Name '$ssh_key_name' is not valid for SSH key" && exit 1
  [[ -z $age_key_file ]] && gum log --level error "Location '$age_key_file' is not valid for storing age private key" && exit 1
}

function main {
  ssh_key_file="$HOME/.ssh/$ssh_key_name"
  mkdir -p "$(dirname "$age_key_file")"

  gum spin --spinner dot --title "Generating SSH key..." \
    -- ssh-keygen -t ed25519 -P "" -f "$ssh_key_file"
  gum spin --spinner dot --title "Saving private age key..." \
    -- ssh-to-age -private-key -i "$ssh_key_file" >"$age_key_file"

  gum log --level info "Public age key is: $(age-keygen -y "$age_key_file")"
}

parse-args
main
