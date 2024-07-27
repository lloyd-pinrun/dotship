{
  config,
  inputs,
  nix,
  withSystem,
  ...
}:
with nix; {
  imports = [./nixos-anywhere.nix];
  config.flake = let
    nodeAttr = getAttrFromPath ["profiles" "system" "raw"];
    nodes = type: mapAttrs (_: nodeAttr) config.canivete.deploy.${type}.nodes;
  in {
    nixosConfigurations = nodes "nixos";
    darwinConfigurations = nodes "darwin";
    nixOnDroidConfigurations = nodes "droid";
  };
  config.canivete.deploy = {
    home.modules = {};
    system.modules.nix = {pkgs, ...}: {
      nix.extraOptions = "experimental-features = nix-command flakes auto-allocate-uids";
      nix.package = pkgs.nixVersions.latest;
    };
    nixos.defaultSystem = "x86_64-linux";
    nixos.systemBuilder = inputs.nixpkgs.lib.nixosSystem;
    nixos.systemActivationCommands = let
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
    darwin.defaultSystem = "aarch64-darwin";
    darwin.systemBuilder = inputs.nix-darwin.lib.darwinSystem;
    darwin.systemActivationCommands = ["sudo HOME=/var/root \"$closure/activate\""];
    droid.defaultSystem = "aarch64-linux";
    droid.systemBuilder = inputs.nix-on-droid.lib.nixOnDroidConfiguration;
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
      config.specialArgs = {inherit nix;} // (with inputs.self.nixos-flake.lib; specialArgsFor.${type.name} or specialArgsFor.common);
      config.homeModules = config.canivete.deploy.home.modules;
      options = {
        specialArgs = mkOption {type = attrsOf anything;};
        defaultSystem = mkSystemOption {};
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
                profiles.system = {
                  attr = "system.build.toplevel";
                  cmds = type.config.systemActivationCommands;
                  builder = module:
                    withSystem node.config.system (
                      {
                        pkgs,
                        system,
                        ...
                      }: let
                        _builder = type.config.systemBuilder;
                        inherit (type.config) specialArgs;
                        # Some tools call this extraSpecialArgs for some reason...
                        extraArgs =
                          if (functionArgs _builder) ? extraSpecialArgs
                          then {extraSpecialArgs = specialArgs;}
                          else {inherit specialArgs;};
                        args =
                          extraArgs
                          // {
                            inherit pkgs system;
                            modules = attrValues config.canivete.deploy.system.modules ++ attrValues type.config.modules ++ [module];
                          };
                      in
                        _builder args
                    );
                };
              }
              {
                profiles = flip mapAttrs node.config.home (_: _module: {
                  attr = "home.activationPackage";
                  builder = __module: withSystem node.config.system ({pkgs, ...}: inputs.self.nixos-flake.lib.mkHomeConfiguration pkgs __module);
                  module.imports = attrValues type.config.homeModules ++ [_module];
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
                sshFlags = mkOption {
                  type = str;
                  default = "";
                };
              };
              target = {
                host = mkOption {
                  type = str;
                  default = node.name;
                };
                sshFlags = mkOption {
                  type = str;
                  default = "";
                };
              };
              profiles = mkOption {
                default = {};
                type = attrsOf (submodule (profile @ {name, ...}: {
                  options = {
                    attr = mkOption {type = str;};
                    builder = mkOption {type = functionTo raw;};
                    module = mkOption {type = deferredModule;};
                    raw = mkOption {type = raw;};
                    opentofu = mkOption {type = deferredModule;};
                    cmds = mkOption {type = listOf str;};
                    build = node.options.build // {default = node.config.build;};
                    target = node.options.target // {default = node.config.target;};
                  };
                  config.raw = with profile.config; builder module;
                  config.opentofu = {pkgs, ...}: {
                    config = let
                      sshFlags = "-o ControlMaster=auto -o ControlPath=/tmp/%C -o ControlPersist=60 -o StrictHostKeyChecking=accept-new";
                      nixFlags = "--extra-experimental-features \"nix-command flakes\"";
                      name = concatStringsSep "_" [type.name node.name profile.name];
                      path = concatStringsSep "." ["canivete.deploy" type.name "nodes" node.name "profiles" profile.name "raw.config" profile.config.attr];
                      drv = "\${ data.external.${name}.result.drv }";
                      inherit (profile.config) build target;
                    in
                      mkMerge [
                        {
                          data.external.${name}.program = pkgs.execBash ''
                            nix ${nixFlags} path-info --derivation ${inputs.self}#${path} | \
                                ${pkgs.jq}/bin/jq --raw-input '{"drv":.}'
                          '';
                          resource.null_resource.${name} = {
                            triggers.drv = drv;
                            # TODO does NIX_SSHOPTS serve a purpose outside of nixos-rebuild
                            provisioner.local-exec.command = ''
                              if [[ $(hostname) == ${build.host} ]]; then
                                  closure=$(nix-store --verbose --realise ${drv})
                              else
                                  export NIX_SSHOPTS="${sshFlags} ${build.sshFlags}"
                                  nix ${nixFlags} copy --derivation --to ssh-ng://${build.host} ${drv}
                                  closure=$(ssh ${sshFlags} ${build.host} nix-store --verbose --realise ${drv})
                                  nix ${nixFlags} copy --from ssh-ng://${build.host} "$closure"
                              fi

                              if [[ $(hostname) == ${target.host} ]]; then
                                  ${concatStringsSep "\n" profile.config.cmds}
                              else
                                  export NIX_SSHOPTS="${sshFlags} ${target.sshFlags}"
                                  nix ${nixFlags} copy --to ssh-ng://${target.host} "$closure"
                                  ${concatStringsSep "\n" (forEach profile.config.cmds (cmd: "ssh ${sshFlags} ${node.name} ${cmd}"))}
                              fi
                            '';
                          };
                        }
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
