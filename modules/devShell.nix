{
  config,
  nix,
  ...
}:
with nix; {
  options.canivete.devShell.name = mkOption {
    type = str;
    default = "can";
    description = "Name of the primary project executable";
  };
  config.perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.default = pkgs.writeShellApplication {
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
    devShells.default = pkgs.mkShell {
      inputsFrom = attrValues (removeAttrs self'.devShells ["default"]);
      packages = [self'.packages.default];
    };
  };
}
