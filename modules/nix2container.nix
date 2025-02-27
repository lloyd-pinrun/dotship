{
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption pipe recursiveUpdate types;
  inherit (types) anything attrsOf package str submodule;
in {
  perSystem = mkIf (inputs ? nix2container) ({
    canivete,
    inputs',
    pkgs,
    self',
    ...
  }: {
    options.canivete.nix2container = mkOption {
      default = {};
      type = attrsOf (submodule ({
        name,
        config,
        ...
      }: {
        options = {
          registry = mkOption {
            type = str;
            default = "docker.io";
          };
          repository = mkOption {
            type = str;
            default = name;
          };
          package = mkOption {
            type = package;
            default = self'.packages.${name} or pkgs.${name};
          };
          tag = mkOption {
            type = str;
            default = config.package.version;
          };
          args = mkOption {
            type = attrsOf anything;
            default = {};
          };
          image = mkOption {
            type = package;
            default = pipe config.args [
              (recursiveUpdate {
                name = "${config.registry}/${config.repository}";
                inherit (config) tag;
                config.entrypoint = ["${config.package}/bin/${config.package.meta.mainProgram or name}"];
              })
              inputs'.nix2container.packages.nix2container.buildImage
            ];
          };
        };
      }));
    };
  });
}
