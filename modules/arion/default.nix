flake @ {
  inputs,
  nix,
  ...
}:
with nix; {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: let
    # Arion has no argument to prefer buildLayeredImage when streamLayeredImage doesn't work across systems
    arion-patched = pkgs.applyFlakePatches {
      name = "arion-patched-src";
      src = inputs.arion;
      patches = [./arion.patch];
    };
    # Containers rely on the Linux kernel, so for this to work on a Darwin client, configure distributed builds
    system'' = replaceStrings ["darwin"] ["linux"] system;

    # Module shorthand
    cfg = config.canivete.arion;
    inherit (inputs.self.canivete.${system''}.pkgs) pkgs;
    modules = attrValues cfg.modules;
  in {
    options.canivete.arion = {
      modules = mkModulesOption {};
      composition = mkOption {
        type = raw;
        description = "Evaluated arion configuration";
        default = arion-patched.lib.eval {inherit modules pkgs;};
      };
      yaml = mkOption {
        type = package;
        description = "docker-compose YAML output";
        default = cfg.composition.config.out.dockerComposeYaml;
      };
      basePackage = mkOption {
        type = package;
        description = "Base arion package to use";
        default = arion-patched.packages.${system}.arion;
      };
      finalPackage = mkOption {
        type = package;
        description = "Final arion executable";
        default = pkgs.wrapProgram cfg.basePackage "arion" "arion" "--add-flags \"--prebuilt-file ${cfg.yaml}\"" {};
      };
    };
    # TODO why does this cause a nix daemon disconnection? move-docs.sh missing? cross platform is HARD
    # config.canivete.just.recipes."arion *ARGS" = "${getExe cfg.finalPackage} {{ ARGS }}";
    config.canivete.arion.modules.builtin = {
      # Also share self' of the Linux system variant
      config._module.args.self'' = flake.config.perInput system'' inputs.self;
      config.project.name = mkDefault config.canivete.devShell.name;
      # Mismatched systems should buildLayeredImage to allow running on host
      options.services = mkOption {
        type = attrsOf (submodule {
          config.image.asStream = system == system'';
        });
      };
      config.services = {};
    };
  };
}
