{
  inputs,
  nix,
  ...
}: {
  imports = [inputs.nix-topology.flakeModule];
  canivete.deploy.nixos.modules.topology = inputs.nix-topology.nixosModules.default;
  perSystem.imports = [(nix.mkAliasOptionModule ["canivete" "topology"] ["topology"])];
}
