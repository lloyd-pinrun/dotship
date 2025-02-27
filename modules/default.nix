{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) getAttr mapAttrs mergeAttrsList mkDefault;
in {
  imports = [
    ./deploy
    ./kubenix
    ./opentofu
    ./scripts
    ./sops

    ./arion.nix
    ./canivete.nix
    ./climod.nix
    ./devShells.nix
    ./dream2nix.nix
    ./just.nix
    ./meta.nix
    ./pkgs.nix
    ./pre-commit.nix
    ./processes.nix
    ./schemas.nix
  ];
  systems = mkDefault (import inputs.systems);

  # Expose everything canivete to flake top level
  flake.canivete = mergeAttrsList [
    config.canivete
    (mapAttrs (_: getAttr "canivete") config.allSystems)
    {inherit inputs;}
  ];
}
