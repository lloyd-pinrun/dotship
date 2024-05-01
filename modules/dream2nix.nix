{
  inputs,
  nix,
  ...
}:
with nix; {
  options.perSystem = mkPerSystemOption (perSystem @ {pkgs, ...}: let
    cfg = perSystem.config.canivete.dream2nix;
  in {
    options.canivete.dream2nix = {
      sharedModules = mkOption {
        type = listOf deferredModule;
        default = [];
        description = mdDoc "Dream2Nix modules used in all packages";
      };
      sharedShells = mkOption {
        type = listOf package;
        default = [];
        description = mdDoc "Shells shared by package devShells";
      };
      packages = mkOption {
        type = attrsOf (submodule ({config, ...}: {
          options = {
            module = mkOption {
              type = deferredModule;
              description = mdDoc "Primary module to pass specific package config";
            };
            modules = mkOption {
              type = listOf deferredModule;
              default = concat cfg.sharedModules [config.module];
              description = mdDoc "All modules used to build package";
            };
            package = mkOption {
              type = package;
              default = inputs.dream2nix.lib.evalModules {
                inherit (config) modules;
                packageSets.nixpkgs = pkgs;
              };
              description = mdDoc "Final package built with Dream2Nix";
            };
            devShell = mkOption {
              type = nullOr package;
              default = pkgs.mkShell {
                inputsFrom = concat cfg.sharedShells (toList (config.package.devShell or []));
              };
              description = mdDoc "Development shell for this package";
            };
          };
        }));
        default = {};
        description = mdDoc "Dream2Nix packages";
      };
    };
    config = mkMerge [
      {
        packages = mapAttrs (_: getAttr "package") cfg.packages;
        canivete.dream2nix.sharedModules = toList {
          paths.projectRoot = toString inputs.self;
          paths.projectRootFile = "flake.nix";
        };
      }
      (mkIf (perSystem.config.canivete ? devShell) {
        devShells = mapAttrs (_: getAttr "devShell") cfg.packages;
      })
    ];
  });
}
