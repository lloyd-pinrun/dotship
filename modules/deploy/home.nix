{
  config,
  inputs,
  nix,
  withSystem,
  ...
}:
with nix; {
  options.canivete.deploy.home = {
    modules = mkModulesOption {};
    nodes = mkOption {
      default = {};
      type = attrsOf (coercedTo deferredModule (module:
        withSystem "aarch64-darwin" ({pkgs, ...}:
          inputs.self.nixos-flake.lib.mkHomeConfiguration pkgs {
            imports = attrValues config.canivete.deploy.home.modules ++ [module];
          }))
      raw);
    };
  };
}
