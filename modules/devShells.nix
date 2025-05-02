{
  perSystem = {
    dotship,
    config,
    lib,
    pkgs,
    self',
    ...
  }: let
    inherit (dotship.lib.options) mkEnabledOption;

    inherit
      (lib)
      filterAttrs
      getAttr
      mapAttrs
      mkIf
      mkMerge
      mkOption
      pipe
      types
      ;

    inherit (pkgs) mkShell;

    inherit (config.dotship) devShells;
  in {
    options.dotship.devShells = {
      enable = mkEnabledOption "modularized devshell configuration";

      shells = mkOption {
        type = types.lazyAttrsOf (types.submodule ({
          config,
          name,
          ...
        }: {
          options = {
            name = mkOption {
              type = types.str;
              readOnly = true;
              default = name;
              description = "Name of the primary project executable";
            };

            packages = mkOption {
              type = types.listOf types.package;
              default = [];
              description = "Packages to include in development shell";
            };

            inputsFrom = mkOption {
              type = types.listOf types.package;
              default = [];
              description = "Development shells to include in the default";
            };

            shellHook = mkOption {
              type = types.lines;
              default = "";
              description = "Hook to run in devshell";
            };

            shell = mkOption {
              type = types.package;
              default = mkShell {inherit (config) name packages inputsFrom shellHook;};
              description = "actual shell";
            };
          };
        }));
      };
    };

    config = mkIf devShells.enable {
      devShells = pipe devShells.shells [
        (filterAttrs (name: _: name != "shared"))
        (mapAttrs (_: getAttr "shell"))
      ];

      dotship.devShells.shells = mkMerge [
        {
          shared = {};
          default.inputsFrom = [devShells.shells.shared.shell];
        }
        (pipe self'.packages [
          (filterAttrs (name: _: name != "default"))
          (mapAttrs (_: _: {inputsFrom = [devShells.shells.shared.shell];}))
        ])
      ];
    };
  };
}
