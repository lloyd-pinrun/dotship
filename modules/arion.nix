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
      mkDefault
      mkEnableOption
      mkOption
      mkPackageOption
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

            package = mkPackageOption pkgs "arion" {
              nullable = true;
              default =
                if inputs ? arion
                then arion.flake.packages.${system}.arion
                else null;
            };

            finalPackage = mkOption {
              type = types.nullOr types.package;
              readOnly = true;

              default = let
                inherit (config) package yaml;
                inherit (pkgs) wrapProgram;
              in
                if package != null
                then wrapProgram package "arion" "arion" "--add-flags \"--prebuilt-file ${yaml}\"" {}
                else null;

              description = "Final arion package";
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
        default = {};
      };
    };

    # config = mkIf (arion.enable && config.just.enable) (mkMerge [
    # ]);
  };
}
