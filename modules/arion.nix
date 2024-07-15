{
  inputs,
  nix,
  ...
}:
with nix; {
  options.perSystem = mkPerSystemOption ({
    config,
    flake,
    pkgs,
    system,
    ...
  }: {
    options.canivete.arion.modules = mkModulesOption {};
    config.canivete.arion.modules.name.project.name = mkDefault config.canivete.devShell.name;
    config.canivete.devShell.apps.arion.script = let
      modules = attrValues config.canivete.arion.modules;
      docker-compose-yaml = inputs.arion.lib.build {
        inherit modules;
        # Containers rely on the Linux kernel, so for this to work on a Darwin client, configure distributed builds
        inherit (flake.config.canivete.${replaceStrings ["darwin"] ["linux"] system}.pkgs) pkgs;
      };
    in "${getExe inputs.arion.packages.${system}.arion} --prebuilt-file ${docker-compose-yaml} \"$@\"";
  });
}
