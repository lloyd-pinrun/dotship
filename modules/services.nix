{inputs, ...}: {
  imports = [inputs.process-compose.flakeModule];
  perSystem = {
    config,
    lib,
    ...
  }: let
    inherit (lib) mkAliasOptionModule mkIf getExe mkMerge;
    cfg = config.canivete.process-compose;
  in {
    imports = [(mkAliasOptionModule ["canivete" "process-compose"] ["process-compose"])];
    config = mkMerge [
      (mkIf config.canivete.just.enable {canivete.just.recipes."services *ARGS" = "${getExe cfg.services.outputs.package} {{ ARGS }}";})
      {canivete.process-compose.services.imports = [inputs.services.processComposeModules.default];}
    ];
  };
}
