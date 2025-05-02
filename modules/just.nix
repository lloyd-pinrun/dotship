{
  perSystem = {
    dotship,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (builtins) attrNames attrValues getAttr;

    inherit (dotship.lib.options) mkEnabledOption;

    inherit (lib) mkIf mkMerge types;
    inherit (lib.attrsets) filterAttrs setAttrByPath;
    inherit (lib.lists) toList;
    inherit (lib.meta) getExe;
    inherit (lib.options) mkOption;
    inherit (lib.strings) concatStringsSep;
    inherit (lib.trivial) pipe;

    inherit (pkgs) writeText wrapProgram mkShell;

    inherit (config.dotship) just;
  in {
    options.dotship.just = {
      enable = mkEnabledOption "just command runner";

      recipes = mkOption {
        type = types.lazyAttrsOf (types.coercedTo types.str (setAttrByPath ["command"])
          (types.submodule ({
            config,
            name,
            ...
          }: {
            options.enable = mkEnabledOption name;
            options.command = mkOption {
              type = types.str;
              description = "Actual command to run as part of this recipe.";
            };
            options.recipe = mkOption {
              type = types.str;
              description = "Literal recipe in justfile";
              default = ''
                ${name}:
                  ${config.command}
              '';
            };
          })));
        description = "Commands to include in just";
        default = {};
      };

      defaultRecipe = mkOption {
        type = types.enum (attrNames just.recipes);
        description = "Recipe to run by default with just";
        default = "list";
      };

      justFile = mkOption {
        type = types.package;
        description = "Justfile with recipe commands";
        default = pipe just.recipes [
          (filterAttrs (_: getAttr "enable"))
          (recipes: toList (recipes.${just.defaultRecipe} or []) ++ attrValues (removeAttrs recipes [just.defaultRecipe]))
          (map (getAttr "recipe"))
          (concatStringsSep "\n")
          (writeText "justfile")
        ];
      };

      basePackage = mkOption {
        type = types.package;
        description = "Base just package to use";
        default = pkgs.just;
      };

      finalPackage = mkOption {
        type = types.package;
        readOnly = true;
        description = "Final just executable";
        default = wrapProgram just.basePackage "just" "just" "--add-flags \"--justfile ${just.justFile}\"" {};
      };

      devShell = mkOption {
        type = types.package;
        description = "Development shell with just executable";
        default = mkShell {
          packages = [just.finalPackage];
          shellHook = "export JUST_WORKING_DIRECTORY=\"$(${getExe pkgs.git} rev-parse --show-toplevel)\"";
        };
      };
    };

    config = mkMerge [
      {dotship.just.recipes.list = "@just --list";}
      (mkIf config.dotship.devShells.enable {
        dotship.devShells.shells.shared.inputsFrom = [just.devShell];
      })
    ];
  };
}
