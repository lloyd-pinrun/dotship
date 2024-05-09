{
  config,
  inputs,
  nix,
  ...
}:
with nix; {
  options.canivete.arion.modules = mkModulesOption {};
  config.canivete.arion.modules.name.project.name = mkDefault config.canivete.devShell.name;
  config.perSystem = {
    inputs',
    pkgs,
    ...
  }: let
    docker-compose-yaml = inputs.arion.lib.build {modules = attrValues config.canivete.arion.modules;};
  in {
    packages.arion = pkgs.writeShellApplication {
      name = "arion";
      text = "${getExe inputs'.arion.packages.arion} --prebuilt-file ${docker-compose-yaml} \"$@\"";
    };
  };
}
