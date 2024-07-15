flake @ {
  inputs,
  nix,
  ...
}:
with nix; {
  options.perSystem = mkPerSystemOption ({
    config,
    system,
    ...
  }: let
    # Containers rely on the Linux kernel, so for this to work on a Darwin client, configure distributed builds
    system'' = replaceStrings ["darwin"] ["linux"] system;
  in {
    options.canivete.arion.modules = mkModulesOption {};
    config.canivete.arion.modules.builtin = {
      # Also share self' of the Linux system variant
      _module.args.self'' = flake.config.perInput system'' inputs.self;
      project.name = mkDefault config.canivete.devShell.name;
    };
    config.canivete.devShell.apps.arion.script = let
      inherit (inputs.self.canivete.${system''}.pkgs) pkgs;
      modules = attrValues config.canivete.arion.modules;
      docker-compose-yaml = inputs.arion.lib.build {inherit modules pkgs;};
    in "${getExe inputs.arion.packages.${system}.arion} --prebuilt-file ${docker-compose-yaml} \"$@\"";
  });
}
