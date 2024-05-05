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
      excludeShellChecks = ["SC2015"];
      text = ''
        nixCmd() {
          nix --show-trace --allow-import-from-derivation \
            --extra-experimental-features "nix-command flakes auto-allocate-uids configurable-impure-env" \
            "$@"
        }
        [[ -z ''${1-} || $1 == default ]] && nixCmd flake show || nixCmd run ".#$1" -- "''${@:2}"
      '';
    };
    devShells.default = pkgs.mkShell {
      inputsFrom = attrValues (removeAttrs self'.devShells ["default"]);
      packages = [self'.packages.default];
    };
  };
}
