{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkDefault mergeAttrs mapAttrs getAttr;
in {
  imports = [
    ./arion
    ./deploy
    ./dream2nix
    ./kubenix
    ./scripts

    ./canivete.nix
    ./devShells.nix
    ./just.nix
    ./opentofu.nix
    ./people.nix
    ./pkgs.nix
    ./pre-commit.nix
    ./schemas.nix
    ./services.nix
    ./sops.nix
  ];
  systems = with inputs; lib.mkDefault (import systems);

  # Exposes inputs, canivete (with each system), and utils.sh to flake top level
  flake.inputs = inputs;
  flake.canivete = mergeAttrs config.canivete (mapAttrs (_: getAttr "canivete") config.allSystems);
}
