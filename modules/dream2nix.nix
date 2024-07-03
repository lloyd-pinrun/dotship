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
        description = "Dream2Nix modules used in all packages";
      };
      sharedShells = mkOption {
        type = listOf package;
        default = [];
        description = "Shells shared by package devShells";
      };
      packages = mkOption {
        type = attrsOf (submodule ({config, ...}: {
          options = {
            module = mkOption {
              type = deferredModule;
              description = "Primary module to pass specific package config";
            };
            modules = mkOption {
              type = listOf deferredModule;
              default = concat cfg.sharedModules [config.module];
              description = "All modules used to build package";
            };
            package = mkOption {
              type = package;
              default = inputs.dream2nix.lib.evalModules {
                inherit (config) modules;
                packageSets.nixpkgs = pkgs;
              };
              description = "Final package built with Dream2Nix";
            };
            devShell = mkOption {
              type = nullOr package;
              default = pkgs.mkShell {inputsFrom = concat cfg.sharedShells [config.package.devShell];};
              description = "Development shell for this package";
            };
          };
        }));
        default = {};
        description = "Dream2Nix packages";
      };
    };
    config = {
      devShells = mapAttrs (_: getAttr "devShell") cfg.packages;
      packages = mapAttrs (_: getAttr "package") cfg.packages;
      canivete.dream2nix.sharedModules = toList {
        paths.projectRoot = toString inputs.self;
        paths.projectRootFile = "flake.nix";
      };
    };
  });
}
