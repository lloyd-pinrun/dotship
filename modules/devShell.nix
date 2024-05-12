{nix, ...}:
with nix; {
  options.perSystem = mkPerSystemOption ({
    config,
    options,
    pkgs,
    self',
    ...
  }: {
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
      shells = mkOption {
        type = listOf package;
        default = attrValues (removeAttrs self'.devShells ["default"]);
        description = "Development shells to include in the default";
      };
      inputsFrom = options.canivete.devShell.shells // {default = config.canivete.devShell.shells;};
    };
    config = let
      program = pkgs.writeShellApplication {
        inherit (config.canivete.devShell) name;
        text = ''
          if [[ -z ''${1-} || $1 == default ]]; then
              args=(flake show)
          else
              args=(run ".#$1" -- "''${@:2}")
          fi
          ${./utils.sh} nixCmd "''${args[@]}"
        '';
      };
    in {
      canivete.devShell.packages = [pkgs.sops program];
      apps.default = mkApp program;
      devShells.default = pkgs.mkShell {
        inherit (config.canivete.devShell) name packages inputsFrom;
      };
    };
  });
}
