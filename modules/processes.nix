{
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    mapAttrs'
    mkAliasOptionModule
    mkIf
    mkOption
    nameValuePair
    optional
    types
    ;
in {
  imports = optional (inputs ? process-compose) inputs.process-compose.flakeModule;
  perSystem = {config, ...}: {
    imports = optional (inputs ? process-compose) (mkAliasOptionModule ["dotship" "process-compose"] ["process-compose"]);

    options.dotship.process-compose = mkOption {
      type = types.lazyAttrsOf (types.submoduleWith {
        modules = optional (inputs ? services) inputs.services.processComposeMNodules.default;
      });
      default = {};
    };

    config = mkIf config.just.enable {
      just.recipes =
        mapAttrs'
        (name: _: nameValuePair "${name} *ARGS" "nix run .#${name} \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}")
        config.dotship.process-compose;
    };
  };
}
