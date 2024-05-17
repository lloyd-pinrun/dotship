{
  inputs,
  nix,
  ...
}:
with nix; {
  options.perSystem = mkPerSystemOption ({
    config,
    inputs',
    pkgs,
    ...
  }: {
    options.canivete.arion.modules = mkModulesOption {};
    config.canivete.arion.modules.name.project.name = mkDefault config.canivete.devShell.name;
    config.canivete.devShell.apps.arion.script = let
      modules = attrValues config.canivete.arion.modules;
      docker-compose-yaml = inputs.arion.lib.build {inherit modules pkgs;};
    in "${getExe inputs'.arion.packages.arion} --prebuilt-file ${docker-compose-yaml} \"$@\"";
  });
}
