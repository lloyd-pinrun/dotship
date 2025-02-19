{
  perSystem = {
    canivete,
    config,
    lib,
    pkgs,
    self',
    ...
  }: let
    inherit (lib) mkOption types mkMerge mkIf mapAttrs getAttr pipe filterAttrs;
    inherit (types) str listOf package submodule lines attrsOf;
    cfg = config.canivete.devShells;
  in {
    options.canivete.devShells = {
      enable = canivete.mkEnabledOption "Modularized Dev Shell configuration";
      shells = mkOption {
        default = {};
        type = attrsOf (submodule ({
          name,
          config,
          ...
        }: {
          options = {
            name = mkOption {
              type = str;
              readOnly = true;
              default = name;
              description = "Name of the primary project executable";
            };
            packages = mkOption {
              type = listOf package;
              default = [];
              description = "Packages to include in development shell";
            };
            inputsFrom = mkOption {
              type = listOf package;
              default = [];
              description = "Development shells to include in the default";
            };
            shellHook = mkOption {
              type = lines;
              default = "";
              description = "Hook to run in devshell";
            };
            shell = mkOption {
              type = package;
              description = "actual shell";
              default = pkgs.mkShell {inherit (config) name packages inputsFrom shellHook;};
            };
          };
        }));
      };
    };
    config = mkIf cfg.enable {
      devShells = pipe cfg.shells [
        (filterAttrs (name: _: name != "shared"))
        (mapAttrs (_: getAttr "shell"))
      ];
      canivete.devShells.shells = mkMerge [
        {
          shared = {};
          default.inputsFrom = [cfg.shells.shared.shell];
        }
        (pipe self'.packages [
          (filterAttrs (name: _: name != "default"))
          (mapAttrs (_: _: {inputsFrom = [cfg.shells.shared.shell];}))
        ])
      ];
    };
  };
}
