{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) flip isAttrs isFunction mkEnableOption mkIf mkMerge mapAttrs;
in {
  # This is NOT actually supported yet for some reason...
  options.canivete.schemas.enable = mkEnableOption "flake-schemas experimental support";
  config = mkIf config.canivete.schemas.enable {
    flake.schemas = mkMerge [
      inputs.flake-schemas.schemas
      {
        flakeModules = {
          version = 1;
          doc = "flake-parts modules";
          inventory = output: {
            children = flip mapAttrs output (_: module: {
              what = "flake-parts module";
              evalChecks.isModule = isAttrs module || (isFunction module && (builtins.functionArgs module) ? flake-parts-lib);
            });
          };
        };
      }
    ];
  };
}
