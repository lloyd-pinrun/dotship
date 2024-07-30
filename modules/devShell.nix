{nix, ...}:
with nix; {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.canivete.devShell;
  in {
    config.canivete.devShell.shellHook = concatStringsSep "\n" cfg.shellHooks;
    config.devShells.default = pkgs.mkShell {inherit (cfg) name packages inputsFrom shellHook;};
    options.canivete.devShell = {
      name = mkOption {
        type = str;
        default = "can";
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
        type = str;
        readOnly = true;
        description = "Final hook to run in devshell";
      };
      shellHooks = mkOption {
        type = listOf str;
        description = "Hooks to run in devshell";
        default = [];
      };
    };
  };
}
