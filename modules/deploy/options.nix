{
  canivete,
  config,
  inputs,
  lib,
  self,
  withSystem,
  ...
}: let
  inherit (canivete) prefixAttrNames prefixJoin mkModulesOption mkSystemOption;
  inherit (lib) mkOption types mkMerge mkIf pipe concat flatten;
  inherit (types) attrsOf str submodule anything listOf nullOr bool functionTo raw deferredModule;
  specialArgs = {
    inherit canivete;
    flake = {inherit self inputs config;};
  };
in {
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
          type = attrsOf (submodule ({config, name, ...}: {
            imports = [./profiles.nix];
            config = {
              _module.args = specialArgs // {inherit type withSystem;};
              build.sshOptions = ["ControlMaster=auto" "ControlPath=/tmp/%C" "ControlPersist=60" "StrictHostKeyChecking=accept-new"];
              target.sshOptions = config.build.sshOptions;
              install = mkIf (type.name == "nixos") {
                sshOptions = mkMerge [config.target.sshOptions ["User=root"]];
                anywhereFlags = pipe config.install.sshOptions [
                  (map (option: ["--ssh-option" option]))
                  (concat ["--flake" ".#${name}" "--debug"])
                  flatten
                ];
              };
            };
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
                  default = name;
                };
                sshOptions = mkOption {
                  type = listOf str;
                  default = [];
                };
                sshFlags = mkOption {
                  type = str;
                  default = prefixJoin "-o " " " config.build.sshOptions;
                };
              };
              target = {
                host = mkOption {
                  type = str;
                  default = name;
                };
                sshOptions = mkOption {
                  type = listOf str;
                  default = [];
                };
                sshFlags = mkOption {
                  type = str;
                  default = prefixJoin "-o " " " config.target.sshOptions;
                };
              };
              install = {
                enable = mkOption {
                  type = bool;
                  # Currently only support installation method for nixos
                  default = type.name == "nixos";
                };
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
                  default = prefixJoin "-o " " " config.install.sshOptions;
                };
                anywhereFlags = mkOption {
                  type = listOf str;
                  default = [];
                };
              };
            };
          }));
        };
      };
    }));
  };
}
