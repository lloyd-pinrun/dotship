#! /usr/bin/env bash

# shellcheck disable=SC1090
source "$CANIVETE_UTILS"

cluster=
config=
while [[ $# -gt 0 ]]; do
	case $1 in
	--cluster)
		cluster=$2
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
[[ -z ${cluster-} ]] && logfx exit_status=FAILURE level=ERROR <<<"Must specify a --cluster name"

# shellcheck disable=SC2154
run_dir="$CANIVETE_VCS_DIR/opentofu/$cluster"
enc_file="$run_dir/config.enc.yaml"
dec_file="$run_dir/config.yaml"
mkdir -p "$run_dir"
cp -L "$config" "$enc_file"
chmod 644 "$enc_file"
vals eval -s -f "$enc_file" | yq "." --yaml-output >"$dec_file"

enc_kube="$run_dir/kubeconfig.enc"
dec_kube="$run_dir/kubeconfig"
sops --decrypt --input-type yaml --output-type binary "$enc_kube" --output "$dec_kube"

args=(--kubeconfig "$dec_kube" "$@")
if contains apply args; then
	args+=(--filename "$dec_file")
fi
kubectl "${args[@]}"
