{config, ...}: {
  imports = [
    ./filesets.nix
    ./opentofu.nix
    ./pre-commit.nix
    ./systems.nix
    ./lib.nix
  ];
  canivete.lib.lib = config.canivete.filesets.lib;
}
