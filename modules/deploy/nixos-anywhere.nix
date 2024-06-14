{
  # TODO figure out nix-darwin, nix-on-droid, and home-manager install
  # (mkIf (profile.type == "nixos") {
  #   data.external."nixos_eval_${name}_install".program = pkgs.execBash ''
  #     nix eval --raw ''${ var.ROOT }#nixosConfigurations.${name}.config.system.build.diskoScript.drv | \
  #         ${getExe pkgs.jq} --raw-input '{"drv":.}'
  #   '';
  #   # Must be {name}.keys, not keys.{name} to prevent terraform cycle
  #   locals.${name}.keys."etc/ssh/authorized_keys.d/terraform" = {
  #     file = "terraform.pub";
  #     content = "\${ sshkey_ed25519_key_pair.terraform.public_key }";
  #   };
  #   data.external."save-keys-${name}".program = pipe config.locals.${name}.keys [
  #     (mapAttrsToList (remote: attrs: "echo \"${attrs.content}\" > ${attrs.file}"))
  #     # Needs JSON output for this definition to be accepted
  #     (flip concat ["echo '{}'"])
  #     (concatStringsSep "\n")
  #     pkgs.execBash
  #   ];
  #   resource.null_resource."nixos_switch_${name}_install" = {
  #     depends_on = ["null_resource.nixos_switch_relay" "data.external.save-keys-${name}"];
  #     triggers.drv = "\${ data.external.nixos_eval_${name}_install.result.drv }";
  #     triggers.keys = "\${ sha256(jsonencode({ for k, a in local.${name}.keys: k => a.content })) }";
  #     provisioner.local-exec.environment.HOST = mkDefault config.hostname;
  #     provisioner.local-exec.command = ''
  #       set -euo pipefail

  #       extra_files_dir=$(mktemp -d)
  #       trap 'rm -rf "$extra_files_dir"' EXIT

  #       ${pipe config.locals.${name}.keys [
  #         (mapAttrsToList (path: attrs: ''
  #           mkdir -p "$(dirname "$extra_files_dir/${path}")"
  #           install -m444 "${attrs.file}" "$extra_files_dir/${path}"
  #         ''))
  #         (concatStringsSep "\n                ")
  #       ]}

  #       ${getExe pkgs.nixos-anywhere} \
  #           --flake ''${ var.ROOT }#${name} \
  #           --extra-files "$extra_files_dir" \
  #           --build-on-remote \
  #           --debug \
  #           "root@$HOST"
  #     '';
  #   };
  #   resource.null_resource."nixos_switch_${name}" = {
  #     depends_on = ["null_resource.nixos_switch_${name}_install"];
  #     provisioner.local-exec.environment.ACTION = "switch";
  #   };
  # })
}
