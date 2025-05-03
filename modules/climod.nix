{inputs, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit
      (lib)
      mapAttrs'
      mkDefault
      mkEnableOption
      mkIf
      mkOption
      nameValuePair
      types
      ;

    inherit (pkgs) callPackage;

    inherit (config.dotship) climod;
    climodToJust = name: program: nameValuePair "${name} {{ ARGS }}" program.package;
  in {
    options.dotship.climod = {
      enable = mkEnableOption "climod script builder" // {default = inputs ? climod;};

      programs = mkOption {
        type = types.lazyAttrsOf (types.submodule ({
          config,
          name,
          ...
        }: {
          options = {
            builder = mkOption {
              type = types.functionTo types.package;
              default = callPackage (inputs.climod + "/default.nix") {inherit pkgs;};
              description = "Function to create executable with configuration";
            };

            module = mkOption {
              type = types.deferredModule;
              default = {};
              description = "Configuration";
            };

            package = mkOption {
              type = types.package;
              default = config.builder config.module;
              description = "Executable";
            };

            config.module.name = mkDefault name;
          };
        }));
        default = {};
      };
    };

    config = mkIf (climod.enable && config.just.enable) {
      just.recipes = mapAttrs' climodToJust climod.programs;
    };
  };
}
