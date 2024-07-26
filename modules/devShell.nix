{nix, ...}:
with nix; {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.canivete.devShell;
  in {
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
    config = {
      canivete.devShell.packages = [pkgs.sops];
      devShells.default = pkgs.mkShell {inherit (cfg) name packages inputsFrom;};
    };
  };
}
