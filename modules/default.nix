{
  config,
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    getAttr
    mapAttrs
    mergeAttrsList
    mkDefault
    ;
in {
  imports = [
    ./deploy
    # ./kubenix
    ./opentofu
    ./sops

    ./dotship.nix

    ./arion.nix
    ./climod.nix
    ./devShells.nix
    ./just.nix
    ./meta.nix
    ./pkgs.nix
    ./pre-commit.nix
    ./processes.nix
    ./schemas.nix
  ];

  systems = mkDefault (import inputs.systems);

  flake.dotship = mergeAttrsList [
    (config.dotship or {})
    (mapAttrs (_: getAttr "dotship") config.allSystems)
    {inherit inputs;}
  ];
}
