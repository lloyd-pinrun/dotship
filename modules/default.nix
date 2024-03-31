{config, ...}: {
  imports = [
    ./opentofu.nix
    ./pre-commit.nix
    ./systems.nix
    ./lib.nix
    ./devShell.nix
  ];
  perSystem = {config, ...}: {
    devShells.canivete-pre-commit = config.pre-commit.devShell;
  };
}
