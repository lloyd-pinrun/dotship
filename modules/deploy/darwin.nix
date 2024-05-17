{
  config,
  inputs,
  nix,
  withSystem,
  ...
}:
with nix; {
  options.canivete.deploy.darwin = {
    modules = mkModulesOption {};
    nodes = mkOption {
      default = {};
      type = attrsOf (coercedTo deferredModule (module:
        withSystem "aarch64-darwin" ({
          pkgs,
          system,
          ...
        }:
          inputs.nix-darwin.lib.darwinSystem {
            inherit pkgs system;
            specialArgs = inputs.self.nixos-flake.lib.specialArgsFor.darwin // {inherit nix;};
            modules = with config.canivete.deploy; attrValues system.modules ++ attrValues darwin.modules ++ [module];
          }))
      raw);
    };
  };
}
