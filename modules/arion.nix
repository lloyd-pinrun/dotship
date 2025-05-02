{
  config,
  inputs,
  ...
}: let
  inherit (config) perInput;
in {
  perSystem = {
    dotship,
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    inherit (config.dotship) arion;
    inherit (dotship.lib.options) mkFlakeOption mkModulesOption;

    inherit
      (lib)
      attrValues
      getExe
      mkDefault
      mkEnableOption
      mkIf
      mkOption
      replaceStrings
      types
      ;

    modules = attrValues arion.modules;
    system' = replaceStrings ["darwin"] ["linux"] system;

    inherit (inputs.self.dotship.${system'}.pkgs) pkgs;
  in {
    options.dotship.arion = {
      enable = mkEnableOption "arion docker-compose projects" // {default = inputs ? arion;};
      flake = mkFlakeOption "arion" {};

      projects = mkOption {
        type = types.lazyAttrsOf (types.submodule ({
          name,
          config,
          ...
        }: {
          options = {
            modules = mkModulesOption {};

            composition = mkOption {
              type = types.raw;
              default = arion.flake.lib.eval {inherit modules pkgs;};
              description = "Evaluated arion configuration";
            };

            yaml = mkOption {
              type = types.package;
              default = config.composition.config.out.dockerComposeYaml;
              description = "docker-compose YAML output";
            };

            basePackage = mkOption {
              type = types.package;
              default = arion.flake.packages.${system}.arion;
              description = "Base arion package to use";
            };

            finalPackage = mkOption {
              type = types.package;
              default = pkgs.wrapProgram config.basePackage "arion" "arion" "--add-flags \"--prebuilt-file ${config.yaml}\"" {};
              description = "Final arion executable";
            };
          };

          config.modules.builtins = {
            options.services = mkOption {
              type = types.lazyAttrsOf (types.submodule {config.image.asStream = system == system';});
              default = {};
            };

            config._module.args.self = perInput system' inputs.self;
            config.project.name = mkDefault name;
          };
        }));
      };
    };

    config = mkIf (arion.enable && config.dotship.just.enable) {
      dotship.just.recipes."arion *ARGS" = "${getExe arion.finalPackage} {{ ARGS }}";
    };
  };
}
