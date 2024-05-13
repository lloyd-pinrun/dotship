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
    config.apps.arion = let
      modules = attrValues config.canivete.arion.modules;
      docker-compose-yaml = inputs.arion.lib.build {inherit modules pkgs;};
      script = pkgs.writeShellApplication {
        name = "arion";
        text = "${getExe inputs'.arion.packages.arion} --prebuilt-file ${docker-compose-yaml} \"$@\"";
      };
    in
      mkApp script;
  });
}
