#!/usr/bin/env bash

declare name="${DOTSHIP_SOPS_SSH_KEY_NAME:-SOPS}"
declare age_key_file="${DOTSHIP_SOPS_AGE_KEY_FILE-}"
declare ssh_key_file

declare null=/dev/null
declare usage="$0 [-n|--name NAME (default: SOPS)] [-f|--age-key-file AGE_KEY_FILE] [-h|--help]"

function validate {
  if [[ -z ${name+x} ]]; then
    gum log --level error "Name '$name' is not valid for SSH key"
    exit 1
  fi
  if [[ -z ${age_key_file+x} ]]; then
    gum log --level error "Location '$age_key_file' is not valid for storing age private key"
    exit 1
  fi

  ssh_key_file="$HOME/.ssh/$name"
}

function parse-flags {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n | --name)
      name="$2"
      shift
      ;;
    -f | --age-key-file)
      age_key_file="$1"
      shift
      ;;
    -h | --help)
      gum log "$usage"
      exit 0
      ;;
    *) break ;;
    esac
    shift
  done

  validate
}

function main {
  parse-flags "$@"

  mkdir -p "$(dirname "$age_key_file")"

  gum log --level info "Generating SSH key..."
  ssh-keygen -t -ed25519 -P "" -f "$ssh_key_file" &>$null

  gum log --level info "Saving private age key..."
  ssh-to-age -private-key -i "$ssh_key_file" >"$age_key_file" 2>$null

  gum log --level info "Public age key is: $(rage-keygen -y "$age_key_file")"
}

main "$@"
