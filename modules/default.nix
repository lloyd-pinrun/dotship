{
  dot,
  config,
  inputs,
  lib,
  ...
}: {
  imports = [
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
  perSystem._module.args = {inherit dot;};

  flake.dotship = lib.mergeAttrsList [
    (config.dotship or {})
    (builtins.mapAttrs (_: builtins.getAttr "dotship") config.allSystems)
    {
      inherit inputs;
      # NOTE: `dot.options` accessible via `dotship.lib.options`
      lib = {inherit (dot) options;};
    }
  ];
}
