{nix, ...}:
with nix; {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.canivete.devShell;
  in {
    config.devShells.default = pkgs.mkShell {inherit (cfg) name packages inputsFrom;};
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
    };
  };
}
