{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) getAttr mapAttrs mergeAttrsList mkDefault;
in {
  imports = [
    ./arion
    ./deploy
    ./dream2nix
    ./kubenix
    ./opentofu
    ./scripts

    ./canivete.nix
    ./climod.nix
    ./devShells.nix
    ./just.nix
    ./people.nix
    ./pkgs.nix
    ./pre-commit.nix
    ./processes.nix
    ./schemas.nix
    ./sops.nix
  ];
  systems = mkDefault (import inputs.systems);

  # Expose everything canivete to flake top level
  flake.canivete = mergeAttrsList [
    config.canivete
    (mapAttrs (_: getAttr "canivete") config.allSystems)
    {inherit inputs;}
  ];
}
