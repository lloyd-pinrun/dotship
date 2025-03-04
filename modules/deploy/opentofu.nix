{
  canivete,
  lib,
  flake,
  config,
  name,
  node,
  type,
  ...
}: let
  inherit (flake) inputs;
  inherit (canivete) prefixJoin mkIfElse;
  inherit (lib) mkOption types concatStringsSep mkMerge mkIf flip mapAttrsToList replaceStrings;
  inherit (flake.config.canivete.meta) root;
  profile_name = name;
in {
  options.opentofu = mkOption {type = types.deferredModule;};
  config.opentofu = {pkgs, ...}: {
    config = let
      getPath = attr: concatStringsSep "." ["canivete.deploy" type.name "nodes" node.name "profiles" profile_name "raw.config" attr];

      name = concatStringsSep "_" [type.name node.name profile_name];
      path = getPath config.attr;
      drv = "\${ data.external.${name}.result.drv }";
      inherit (config) build target;
      inherit (node.config) install;
      nixFlags = concatStringsSep " " type.config.nixFlags;

      waitScript = host: ''
        timeout=5
        total=300
        elapsed=0

        while ! ${pkgs.openssh}/bin/ssh -q -o ConnectTimeout=$timeout ${host.sshFlags} $HOST exit; do
          elapsed=$((elapsed + timeout))
          if [[ $elapsed -ge $total ]]; then
            echo '{"status":"unavailable"}'
            exit 1
          fi
          sleep $timeout
        done

        echo '{"status":"available"}'
      '';
      setHost = ''eval "$(${pkgs.jq}/bin/jq --raw-output '@sh "HOST=\(.HOST)"')"'';

      rootName = concatStringsSep "_" ["nixos" root "system"];

      protocol = config.sshProtocol;
    in
      mkMerge [
        # Installation
        (mkIf (type.name == "nixos" && install.enable) (mkMerge [
          {
            resource.null_resource."${name}_install".provisioner.local-exec = {
              environment.HOST = install.host;
              command = ''
                set -euo pipefail
                ${waitScript install}
                ${inputs.nixos-anywhere.packages.${pkgs.system}.nixos-anywhere}/bin/nixos-anywhere \
                    ${concatStringsSep " " install.anywhereFlags} $HOST
              '';
            };
            data.external."${name}_ssh-wait".depends_on = ["null_resource.${name}_install"];
          }
          (mkIf (node.name != root) {resource.null_resource."${name}_install".depends_on = ["null_resource.${rootName}"];})
        ]))

        {
          data.external."${name}_ssh-wait" = {
            query.HOST = target.host;
            program = pkgs.execBash ''
              ${setHost}
              ${waitScript target}
            '';
          };
          resource.null_resource.${name}.depends_on = ["data.external.${name}_ssh-wait"];
        }
        (mkIf (node.name != root) {data.external."${name}_ssh-wait".depends_on = ["null_resource.${rootName}"];})

        # Secrets
        (mkMerge (flip mapAttrsToList config.raw.config.canivete.secrets (resource: attr: let
          resource_name = replaceStrings ["."] ["-"] (concatStringsSep "_" [name "secrets" resource]);
          value = "\${ ${resource}.${attr} }";
        in
          mkMerge [
            (mkIf install.enable {resource.null_resource.${resource_name}.lifecycle.replace_triggered_by = ["null_resource.${name}_install"];})
            {
              resource.null_resource.${name}.depends_on = ["null_resource.${resource_name}"];
              resource.null_resource.${resource_name} = {
                depends_on = ["data.external.${name}_ssh-wait"];
                triggers.name = resource;
                triggers.attr = value;
                provisioner.local-exec = {
                  environment.FILE = resource;
                  environment.SECRET = value;
                  environment.HOST = target.host;
                  command = ''
                    set -euo pipefail

                    secret_file="$(mktemp)"
                    trap 'rm -f "$secret_file"' EXIT
                    echo "$SECRET" >"$secret_file"

                    secrets_dir="/private/canivete/secrets"
                    secrets_file="$secrets_dir/$FILE"
                    prefix=$([[ $(hostname) != $HOST ]] && echo "${pkgs.openssh}/bin/ssh $HOST ${target.sshFlags}" || echo "")

                    # Darwin install lacks a -D flag and can't use /dev/stdin so 1 line became 3 separate ssh calls
                    $prefix sudo mkdir -p "$(dirname "$secrets_file")"
                    cat "$secret_file" | $prefix sudo tee "$secrets_file" >/dev/null
                    $prefix sudo chmod 400 "$secrets_file"
                  '';
                };
              };
            }
          ])))

        # Activation
        # TODO does NIX_SSHOPTS serve a purpose outside of nixos-rebuild
        {resource.null_resource.${name}.provisioner.local-exec.environment.HOST = target.host;}
        (mkIfElse (type.name == "droid") {
            data.external.${name} = {
              depends_on = ["data.external.${name}_ssh-wait"];
              query.HOST = target.host;
              program = pkgs.execBash ''
                ${setHost}
                export NIX_SSHOPTS="${target.sshFlags}"
                nix ${nixFlags} copy --to ${protocol}://$HOST ${inputs.self}
                ssh ${target.sshFlags} $HOST nix ${nixFlags} path-info --derivation ${inputs.self}#${path} | \
                    ${pkgs.jq}/bin/jq --raw-input '{"drv":.}'
              '';
            };
            resource.null_resource.${name} = {
              triggers.drv = drv;
              provisioner.local-exec.command = let
                flake_uri = "${inputs.self}#inputs.nix-on-droid.packages.${node.config.system}.nix-on-droid";
              in ''
                set -euo pipefail

                ssh ${target.sshFlags} $HOST nix ${nixFlags} run ${flake_uri} -- switch --flake ${inputs.self}#${node.name}
              '';
            };
          } {
            data.external.${name}.program = pkgs.execBash ''
              nix ${nixFlags} path-info --derivation .#${path} | \
                  ${pkgs.jq}/bin/jq --raw-input '{"drv":.}'
            '';
            resource.null_resource.${name} = {
              triggers.drv = drv;
              provisioner.local-exec.environment.BUILD_HOST = build.host;
              provisioner.local-exec.command = ''
                set -euo pipefail

                if [[ $(hostname) == $BUILD_HOST ]]; then
                    closure=$(nix-store --verbose --realise ${drv})
                else
                    export NIX_SSHOPTS="${build.sshFlags}"
                    nix ${nixFlags} copy --derivation --to ${protocol}://$BUILD_HOST ${drv}
                    closure=$(${pkgs.openssh}/bin/ssh ${build.sshFlags} $BUILD_HOST nix-store --verbose --realise ${drv})
                fi

                if [[ $(hostname) == $HOST ]]; then
                    ${concatStringsSep "\n" config.cmds}
                else
                    if [[ $BUILD_HOST != $HOST ]]; then
                       export NIX_SSHOPTS="${target.sshFlags}"
                       nix ${nixFlags} copy --no-check-sigs --from ${protocol}://$BUILD_HOST --to ${protocol}://$HOST "$closure"
                    fi
                    ${prefixJoin "${pkgs.openssh}/bin/ssh ${target.sshFlags} $HOST " "\n" config.cmds}
                fi
              '';
            };
          })
      ];
  };
}
