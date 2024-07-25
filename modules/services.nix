{
  inputs,
  nix,
  ...
}:
with nix; {
  imports = [inputs.process-compose-flake.flakeModule];
  perSystem = {config, ...}: {
    imports = [(mkAliasOptionModule ["canivete" "process-compose"] ["process-compose"])];
    canivete.just.recipes."services *ARGS" = "${getExe config.canivete.process-compose.services.outputs.package} {{ ARGS }}";
    canivete.process-compose.services.imports = [inputs.services-flake.processComposeModules.default];
  };
}
