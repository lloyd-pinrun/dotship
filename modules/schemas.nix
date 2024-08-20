{
  config,
  inputs,
  nix,
  ...
}:
with nix; {
  options.canivete = mkOption {
    type = submodule {freeformType = attrsOf anything;};
    default = {};
  };
  config.flake = {
    inherit inputs;
    canivete = mergeAttrs config.canivete (mapAttrs (_: getAttr "canivete") config.allSystems);
    schemas =
      inputs.flake-schemas.schemas
      // {
        flakeModules = {
          version = 1;
          doc = "flake-parts modules";
          inventory = output: {
            children = flip mapAttrs output (_: module: {
              what = "flake-parts module";
              evalChecks.isModule = isAttrs module || (isFunction module && (functionArgs module) ? flake-parts-lib);
            });
          };
        };
      };
  };
}
