{
  inputs,
  nix,
  ...
}:
with nix; {
  imports = [inputs.process-compose-flake.flakeModule];
  perSystem.imports = [(mkAliasOptionModule ["canivete" "process-compose"] ["process-compose"])];
  perSystem.canivete.process-compose.services.imports = [inputs.services-flake.processComposeModules.default];
}
