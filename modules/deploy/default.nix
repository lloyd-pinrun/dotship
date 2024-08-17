{
  config,
  inputs,
  self,
  nix,
  withSystem,
  ...
}:
with nix; let
  inherit (config.canivete.people) me;
  specialArgs = {
    inherit nix;
    flake = {inherit self inputs config;};
  };
  prefixJoin = prefix: separator: concatMapStringsSep separator (option: "${prefix}${option}");
in {
  config.flake = let
    nodeAttr = getAttrFromPath ["profiles" "system" "raw"];
    nodes = type: mapAttrs (_: nodeAttr) config.canivete.deploy.${type}.nodes;
  in {
    nixosConfigurations = nodes "nixos";
    darwinConfigurations = nodes "darwin";
    nixOnDroidConfigurations = nodes "droid";
  };
  config.canivete.deploy = {
    system.modules.secrets = {
      options.canivete.secrets = mkOption {
        type = attrsOf str;
        description = "Map of terraform resource to attribute to generate a secret from in /run/secrets";
        default = {};
      };
    };
    nixos = {
      modules.home-manager = {
        imports = [inputs.home-manager.nixosModules.home-manager];
        home-manager.extraSpecialArgs = specialArgs;
        home-manager.sharedModules = attrValues config.canivete.deploy.nixos.homeModules;
      };
      defaultSystem = "x86_64-linux";
      systemBuilder = inputs.nixpkgs.lib.nixosSystem;
      systemActivationCommands = let
        systemdFlags = concatStringsSep " " [
          "--collect --no-ask-password --pipe --quiet --same-dir --wait"
          "--setenv LOCALE_ARCHIVE --setenv NIXOS_INSTALL_BOOTLOADER="
          # Using the full 'nixos-rebuild-switch-to-configuration' name on sirver would fail to collect/cleanup
          "--service-type exec --unit nixos-switch"
        ];
      in [
        "sudo nix-env --profile /nix/var/nix/profiles/system --set \"$closure\""
        "sudo systemd-run ${systemdFlags} \"$closure/bin/switch-to-configuration\" switch"
      ];
    };
    darwin.defaultSystem = "aarch64-darwin";
    darwin.systemBuilder = inputs.nix-darwin.lib.darwinSystem;
    darwin.systemActivationCommands = ["sudo HOME=/var/root \"$closure/activate\""];
    droid = {
      # Unfortunately this still requires impure evaluation
      nixFlags = ["--impure"];
      defaultSystem = "aarch64-linux";
      systemBuilder = inputs.nix-on-droid.lib.nixOnDroidConfiguration;
      systemAttr = "build.activationPackage";
      systemActivationCommands = ["$closure/activate"];
      modules.home-manager = {
        home-manager.extraSpecialArgs = specialArgs;
        home-manager.sharedModules = attrValues config.canivete.deploy.droid.homeModules;
      };
    };
  };
  config.perSystem.canivete.opentofu.workspaces.deploy = {
    plugins = ["opentofu/null" "opentofu/external"];
    modules.default.imports = pipe config.canivete.deploy [
      (mapAttrsToList (_:
        flip pipe [
          (getAttr "nodes")
          (mapAttrsToList (_:
            flip pipe [
              (getAttr "profiles")
              (mapAttrsToList (_: getAttr "opentofu"))
            ]))
        ]))
      flatten
    ];
  };
  options.canivete.deploy = mkOption {
    default = {};
    type = attrsOf (submodule (type @ {name, ...}: {
      config = mkMerge [
        {
          inherit specialArgs;
          nixFlags = ["--extra-experimental-features \"nix-command flakes\""];
        }
        (mkIf (type.name != "system") {
          modules = prefixAttrNames "system." config.canivete.deploy.system.modules;
          homeModules = prefixAttrNames "system.home." config.canivete.deploy.system.homeModules;
        })
      ];
      options = {
        nixFlags = mkOption {type = listOf str;};
        specialArgs = mkOption {type = attrsOf anything;};
        defaultSystem = mkSystemOption {};
        systemAttr = mkOption {
          type = str;
          description = "Attribute of system package to build";
          default = "system.build.toplevel";
        };
        systemBuilder = mkOption {
          # null for common modules under "system" type
          type = nullOr (functionTo raw);
          default = null;
        };
        systemActivationCommands = mkOption {
          # empty for common modules under "system" type
          type = listOf str;
          default = [];
        };
        modules = mkModulesOption {};
        homeModules = mkModulesOption {};
        nodes = mkOption {
          default = {};
          type = attrsOf (submodule (node @ {name, ...}: {
            config = mkMerge [
              {
                build.sshOptions = ["ControlMaster=auto" "ControlPath=/tmp/%C" "ControlPersist=60" "StrictHostKeyChecking=accept-new"];
                target.sshOptions = node.config.build.sshOptions;
                install = mkIf (type.name == "nixos") {inherit (node.config.target) sshOptions;};
                profiles.system = {
                  attr = type.config.systemAttr;
                  cmds = type.config.systemActivationCommands;
                  modules = mergeAttrs type.config.modules (
                    if type.name != "droid"
                    then {hostname.networking.hostName = name;}
                    else {}
                  );
                  builder = modules:
                    withSystem node.config.system (
                      {pkgs, ...}: let
                        _builder = type.config.systemBuilder;
                        # Some tools call this extraSpecialArgs for some reason...
                        argsKey =
                          if type.name == "droid"
                          then "extraSpecialArgs"
                          else "specialArgs";
                        args = {
                          ${argsKey} = type.config.specialArgs;
                          inherit pkgs;
                          modules = attrValues modules;
                        };
                      in
                        _builder args
                    );
                };
              }
              {
                profiles = flip mapAttrs node.config.home (username: module: {
                  inherit module;
                  modules = mergeAttrs type.config.homeModules {username.home = {inherit username;};};
                  attr = "home.activationPackage";
                  builder = modules:
                    withSystem node.config.system (
                      {pkgs, ...}: let
                        _builder = inputs.home-manager.lib.homeManagerConfiguration;
                        args = {
                          inherit pkgs;
                          extraSpecialArgs = specialArgs;
                          modules = attrValues modules;
                        };
                      in
                        _builder args
                    );
                  cmds = ["\"$closure/activate\""];
                  inherit (node.config.profiles.system) build target;
                });
              }
            ];
            options = {
              system = mkSystemOption {default = type.config.defaultSystem;};
              home = mkOption {
                default = {};
                # TODO validate user as member of "people"
                type = attrsOf deferredModule;
              };
              build = {
                host = mkOption {
                  type = nullOr str;
                  default = node.name;
                };
                sshOptions = mkOption {
                  type = listOf str;
                  default = [];
                };
                sshFlags = mkOption {
                  type = str;
                  default = prefixJoin "-o " " " node.config.build.sshOptions;
                };
              };
              target = {
                host = mkOption {
                  type = str;
                  default = node.name;
                };
                sshOptions = mkOption {
                  type = listOf str;
                  default = [];
                };
                sshFlags = mkOption {
                  type = str;
                  default = prefixJoin "-o " " " node.config.target.sshOptions;
                };
              };
              install = {
                enable = mkEnabledOption "nixos-anywhere installation";
                host = mkOption {
                  type = str;
                  default = "";
                };
                sshOptions = mkOption {
                  type = listOf str;
                  default = [];
                };
                sshFlags = mkOption {
                  type = str;
                  default = prefixJoin "-o " " " node.config.install.sshOptions;
                };
              };
              profiles = mkOption {
                default = {};
                type = attrsOf (submodule (profile @ {name, ...}: {
                  options = {
                    attr = mkOption {type = str;};
                    builder = mkOption {type = functionTo raw;};
                    module = mkOption {type = deferredModule;};
                    modules = mkModulesOption {};
                    raw = mkOption {type = raw;};
                    opentofu = mkOption {type = deferredModule;};
                    cmds = mkOption {type = listOf str;};
                    build.host = node.options.build.host // {default = node.config.build.host;};
                    build.sshFlags = node.options.build.sshFlags // {default = node.config.build.sshFlags;};
                    target.host = node.options.target.host // {default = node.config.target.host;};
                    target.sshFlags = node.options.target.sshFlags // {default = node.config.target.sshFlags;};
                  };
                  config.modules.self = profile.config.module;
                  config.modules.canivete = mkIf (profile.name != "system") {options.canivete = node.config.profiles.system.raw.options.canivete;};
                  config.raw = with profile.config; builder modules;
                  config.opentofu = tofu @ {pkgs, ...}: {
                    config = let
                      getPath = attr: concatStringsSep "." ["canivete.deploy" type.name "nodes" node.name "profiles" profile.name "raw.config" attr];

                      name = concatStringsSep "_" [type.name node.name profile.name];
                      path = getPath profile.config.attr;
                      drv = "\${ data.external.${name}.result.drv }";
                      inherit (profile.config) build target;
                      nixFlags = concatStringsSep " " type.config.nixFlags;

                      installPath = getPath "system.build.diskoScript";

                      waitScript = host: ''
                        timeout=5
                        total=300
                        elapsed=0

                        while ! ${pkgs.netcat}/bin/nc -z -w $timeout ${host} 22; do
                          elapsed=$((elapsed + timeout))
                          if [[ $elapsed -ge $total ]]; then
                            echo '{"status":"unavailable"}'
                            exit 1
                          fi
                          sleep $timeout
                        done

                        echo '{"status":"available"}'
                      '';
                    in
                      mkMerge [
                        # Installation
                        (mkIf (type.name == "nixos" && node.config.install.enable) {
                          data.external."${name}_install_ssh-wait".program = pkgs.execBash (waitScript node.config.install.host);
                          data.external."${name}_install".program = pkgs.execBash ''
                            nix ${nixFlags} path-info --derivation ${inputs.self}#${installPath} | \
                                ${pkgs.jq}/bin/jq --raw-input '{"drv":.}'
                          '';
                          resource.null_resource."${name}_install" = {
                            depends_on = ["data.external.${name}_install_ssh-wait"];
                            triggers.drv = "\${ data.external.${name}_install.result.drv }";
                            provisioner.local-exec.command = ''
                              set -euo pipefail

                              ${inputs.nixos-anywhere.packages.${pkgs.system}.nixos-anywhere}/bin/nixos-anywhere \
                                  --flake ${inputs.self}#${node.name} \
                                  --build-on-remote \
                                  --debug \
                                  ${prefixJoin "--ssh-option " " " node.config.install.sshOptions} \
                                  "root@${node.config.install.host}"
                            '';
                          };
                          data.external."${name}_ssh-wait".depends_on = ["null_resource.${name}_install"];
                        })

                        {
                          data.external."${name}_ssh-wait".program = pkgs.execBash (waitScript target.host);
                          resource.null_resource.${name}.depends_on = ["data.external.${name}_ssh-wait"];
                        }

                        # Secrets
                        (mkMerge (flip mapAttrsToList profile.config.raw.config.canivete.secrets (resource: attr: let
                          resource_name = replaceStrings ["."] ["-"] (concatStringsSep "_" [name "secrets" resource]);
                          value = "\${ ${resource}.${attr} }";
                        in mkMerge [
                          {
                            resource.null_resource.${name}.depends_on = ["null_resource.${resource_name}"];
                            resource.null_resource.${resource_name} = {
                              depends_on = ["data.external.${name}_ssh-wait"];
                              triggers.name = resource;
                              triggers.attr = value;
                              provisioner.local-exec = {
                                environment.FILE = resource;
                                environment.SECRET = value;
                                command = ''
                                  set -euo pipefail

                                  secret_file=$(mktemp)
                                  trap 'rm -f "$secret_file"' EXIT

                                  echo "$SECRET" > "$secret_file"
                                  chmod 0444 "$secret_file"

                                  secrets_dir="/canivete/secrets"
                                  ${pkgs.openssh}/bin/ssh ${target.sshFlags} root@${target.host} mkdir -p "$secrets_dir"
                                  ${pkgs.openssh}/bin/scp ${target.sshFlags} "$secret_file" "root@${target.host}:$secrets_dir/$FILE"
                                '';
                              };
                            };
                          }
                          (mkIf node.config.install.enable {
                            resource.null_resource.${resource_name}.triggers.install = "\${ null_resource.${name}_install.triggers.drv }";
                          })
                        ])))

                        # Activation
                        # TODO does NIX_SSHOPTS serve a purpose outside of nixos-rebuild
                        (mkIfElse (type.name == "droid") {
                            data.external.${name} = {
                              depends_on = ["data.external.${name}_ssh-wait"];
                              program = pkgs.execBash ''
                                export NIX_SSHOPTS="${target.sshFlags}"
                                nix ${nixFlags} copy --to ssh-ng://${target.host} ${inputs.self}
                                ssh ${target.sshFlags} ${target.host} nix ${nixFlags} path-info --derivation ${inputs.self}#${path} | \
                                    ${pkgs.jq}/bin/jq --raw-input '{"drv":.}'
                              '';
                            };
                            resource.null_resource.${name} = {
                              triggers.drv = drv;
                              provisioner.local-exec.command = let
                                flake_uri = "${inputs.self}#inputs.nix-on-droid.packages.${node.config.system}.nix-on-droid";
                              in ''
                                set -euo pipefail

                                ssh ${target.sshFlags} ${target.host} nix ${nixFlags} run ${flake_uri} -- switch --flake ${inputs.self}#${node.name}
                              '';
                            };
                          } {
                            data.external.${name}.program = pkgs.execBash ''
                              nix ${nixFlags} path-info --derivation ${inputs.self}#${path} | \
                                  ${pkgs.jq}/bin/jq --raw-input '{"drv":.}'
                            '';
                            resource.null_resource.${name} = {
                              triggers.drv = drv;
                              provisioner.local-exec.command = ''
                                set -euo pipefail

                                if [[ $(hostname) == ${build.host} ]]; then
                                    closure=$(nix-store --verbose --realise ${drv})
                                else
                                    export NIX_SSHOPTS="${build.sshFlags}"
                                    nix ${nixFlags} copy --derivation --to ssh-ng://${build.host} ${drv}
                                    closure=$(ssh ${build.sshFlags} ${build.host} nix-store --verbose --realise ${drv})
                                    nix ${nixFlags} copy --no-check-sigs --from ssh-ng://${build.host} "$closure"
                                fi

                                if [[ $(hostname) == ${target.host} ]]; then
                                    ${concatStringsSep "\n" profile.config.cmds}
                                else
                                    export NIX_SSHOPTS="${target.sshFlags}"
                                    nix ${nixFlags} copy --to ssh-ng://${target.host} "$closure"
                                    ${prefixJoin "ssh ${target.sshFlags} ${target.host} " "\n" profile.config.cmds}
                                fi
                              '';
                            };
                          })
                      ];
                  };
                }));
              };
            };
          }));
        };
      };
    }));
  };
}
