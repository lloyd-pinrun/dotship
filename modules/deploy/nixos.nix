{
  config,
  inputs,
  nix,
  withSystem,
  ...
}:
with nix; {
  options.canivete.deploy.nixos = {
    modules = mkModulesOption {};
    nodes = mkOption {
      default = {};
      type = attrsOf (coercedTo deferredModule (module:
        withSystem "x86_64-linux" ({
          pkgs,
          system,
          ...
        }:
          inputs.nixpkgs.lib.nixosSystem {
            inherit pkgs system;
            specialArgs = inputs.self.nixos-flake.lib.specialArgsFor.nixos // {inherit nix;};
            modules = toList {
              imports = with config.canivete.deploy; attrValues system.modules ++ attrValues nixos.modules ++ [module];
              home-manager.extraSpecialArgs = inputs.self.nixos-flake.lib.specialArgsFor.common // {inherit nix;};
            };
          }))
      raw);
    };
  };
}
