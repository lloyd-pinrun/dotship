{
  config,
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.dotlib.flakeModule
    # keep-sorted start
    ./deploy
    ./development
    ./kubernetes
    ./opentofu
    ./pkgs
    ./sops
    ./vars.nix
    # keep-sorted end
  ];

  systems = lib.mkDefault (import inputs.systems);

  flake.dotship = lib.mergeAttrsList [
    (config.dotship or {})
    (builtins.mapAttrs (_: builtins.getAttr "dotship") config.allSystems)
    {inherit inputs;}
  ];
}
