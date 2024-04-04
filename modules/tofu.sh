#! /usr/bin/env bash

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

file_name="config.tf.json"
root_dir="$(git rev-parse --show-toplevel)"
build_dir="$root_dir/build/$workspace"
build_file="$build_dir/$file_name"
run_dir="$root_dir/run/opentofu/$workspace"
run_file="$run_dir/$file_name"
mkdir -p "$run_dir" "$build_dir"
cp -L "$config" "$build_file"
chmod 644 "$build_file"
vals eval -s -f "$build_file" -o json | jq "." >"$run_file"
tofu "-chdir=$run_dir" "$@"
