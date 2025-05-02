{
  dotship,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config) systems;
  inherit (config.dotship) schemas;

  inherit
    (builtins)
    functionArgs
    isAttrs
    isFunction
    isString
    ;

  inherit
    (lib)
    filterAttrsRecursive
    getExe
    mapAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  inherit (dotship.lib.options) mkFlakeOption mkNullableOption;
in {
  options.dotship.schemas = {
    enable = mkEnableOption "flake-schemas support" // {default = schemas.flakes.schemas != null && schemas.flakes.nix != null;};
    flakes.schemas = mkFlakeOption "flake-schemas" {};
    flakes.nix = mkFlakeOption "nix-flake-schemas" {};

    lib = mkOption {
      type = let
        recursive = types.attrsOf (types.either (types.functionTo types.anything) recursive);
      in
        recursive;
      default = {};
      description = "Helper functions";
    };

    schemas = mkOption {
      type = types.lazyAttrsOf (types.submodule ({config, ...}: {
        options = let
          children = types.lazyAttrsOf (types.submodule {
            options = {
              forSystems = mkNullableOption (types.listOf (types.enum systems)) {description = "system parents";};
              shortDescription = mkNullableOption types.str {description = "short description";};
              derivation = mkNullableOption types.package {description = "actual derivation";};
              evalChecks = mkNullableOption (types.attrsOf types.bool) {description = "evaluation checks";};
              what = mkNullableOption types.str {description = "base type description";};
              isFlakeCheck = mkNullableOption types.bool {description = "whether to test with flake check";};
              children = mkNullableOption children {description = "further tree keys";};
            };
          });
        in {
          version = mkOption {
            type = types.enum [1];
            default = 1;
            description = "flake-schemas version";
          };

          doc = mkOption {
            type = types.str;
            default = "";
            description = "schema description";
          };

          allowIFD = mkNullableOption types.bool {description = "allow import-from-derivation";};

          dotship.children = mkOption {
            type = children;
            default = {};
            description = "actual tree keys";
          };

          inventory = mkOption {
            type = types.functionTo (types.submodule {
              options.children = mkOption {
                type = children;
                description = "tree keys";
              };
            });
            default = _: config.dotship.children;
            description = "how to derive schema hierarchy";
          };
        };
      }));
    };
  };

  config = mkIf schemas.enable {
    flake.schemas = filterAttrsRecursive (name: value: name != "dotship" && value != null) schemas.schemas;
    dotship.schemas.lib = mkMerge [
      inputs.flake-schemas.lib
      {
        checkDerivation = drv:
          (drv.type or null)
          == "derivation"
          && drv ? drvPath
          && drv ? name
          && isString drv.name;

        checkModule = fn: module:
          isAttrs module
          || (isFunction module && fn module);

        eachChild = fn: output: schemas.lib.mkChildren (mapAttrs fn output);
      }
    ];

    dotship.schemas.schemas = mkMerge [
      inputs.flake-schemas.schemas
      {
        flakeModules.inventory = schemas.lib.eachChild (_: module: {
          what = "flake-parts module";
          evalChecks.isModule = schemas.lib.checkModule (mod: (functionArgs mod) ? flake-parts-lib) module;
        });
      }
    ];

    perSystem = {system, ...}: {
      dotship.just.recipes.inspect = "${getExe schemas.flakes.nix.packages.${system}.default} -- flake show";
    };
  };
}
