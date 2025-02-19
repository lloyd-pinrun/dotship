{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) mergeAttrs mapAttrs getAttr;
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
  systems = with inputs; lib.mkDefault (import systems);

  # Exposes inputs, canivete (with each system), and utils.sh to flake top level
  flake.inputs = inputs;
  flake.canivete = mergeAttrs config.canivete (mapAttrs (_: getAttr "canivete") config.allSystems);
}
