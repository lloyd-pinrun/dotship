{
  inputs,
  lib,
  ...
}: {
  imports = [inputs.nix-topology.flakeModule];
  canivete.deploy.nixos.modules.topology = inputs.nix-topology.nixosModules.default;
  perSystem.imports = [(lib.mkAliasOptionModule ["canivete" "topology"] ["topology"])];
}
