#! /usr/bin/env bash

# shellcheck disable=SC1090
source "$CANIVETE_UTILS"

workspace=
config=
while [[ $# -gt 0 ]]; do
	case $1 in
	--workspace)
		workspace=$2
		shift
		;;
	--config)
		config=$2
		shift
		;;
	--)
		shift
		break
		;;
	*) logfx exit_status=FAILURE level=ERROR <<<"Not a valid option: $1" ;;
	esac
	shift
done
[[ -z ${config-} ]] && logfx exit_status=FAILURE level=ERROR <<<"Must specify a --config file"
[[ -z ${workspace-} ]] && logfx exit_status=FAILURE level=ERROR <<<"Must specify a --workspace name"

# shellcheck disable=SC2154
run_dir="$CANIVETE_VCS_DIR/opentofu/$workspace"
enc_file="$run_dir/config.tf.enc.json"
dec_file="$run_dir/config.tf.json"
mkdir -p "$run_dir"
cp -L "$config" "$enc_file"
chmod 644 "$enc_file"
vals eval -s -f "$enc_file" -o json | jq "." >"$dec_file"
tofu "-chdir=$run_dir" "$@"
