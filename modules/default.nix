{
  dot,
  config,
  inputs,
  lib,
  ...
}: {
  imports = [
    # keep-sorted start
    ./development
    ./users.nix
    # keep-sorted end
  ];

  systems = lib.mkDefault (import inputs.systems);
  perSystem._module.args = {inherit dot;};

  flake.dotship = lib.mergeAttrsList [
    (config.dotship or {})
    (builtins.mapAttrs (_: builtins.getAttr "dotship") config.allSystems)
    {inherit inputs;}
  ];
}
