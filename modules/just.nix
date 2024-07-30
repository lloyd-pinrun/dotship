{nix, ...}:
with nix; {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    cfg = config.canivete.just;
  in {
    options.canivete.just = {
      recipes = mkOption {
        type = attrsOf (coercedTo str (setAttrByPath ["command"]) (submodule ({
          config,
          name,
          ...
        }: {
          options.enable = mkEnabledOption name;
          options.command = mkOption {
            type = str;
            description = "Actual command to run as part of this unique recipe";
          };
          options.recipe = mkOption {
            type = str;
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
        type = enum (attrNames cfg.recipes);
        description = "Recipe to run by default with just";
        default = "list";
      };
      justfile = mkOption {
        type = package;
        description = "Justfile with recipe commands";
        default = pipe cfg.recipes [
          (filterAttrs (_: getAttr "enable"))
          (recipes: toList (recipes.${cfg.defaultRecipe} or []) ++ attrValues (removeAttrs recipes [cfg.defaultRecipe]))
          (map (getAttr "recipe"))
          (concatStringsSep "\n")
          (pkgs.writeText "justfile")
        ];
      };
      basePackage = mkOption {
        type = package;
        description = "Base just package to use";
        default = pkgs.just;
      };
      finalPackage = mkOption {
        type = package;
        description = "Final just executable";
        default = pkgs.wrapProgram cfg.basePackage "just" "just" "--add-flags \"--justfile ${cfg.justfile}\"" {};
      };
      devShell = mkOption {
        type = package;
        description = "Development shell with just executable";
        default = pkgs.mkShell {
          packages = [cfg.finalPackage];
          shellHook = "export JUST_WORKING_DIRECTORY=\"$(${getExe pkgs.git} rev-parse --show-toplevel)\"";
        };
      };
    };
    config.canivete.devShell.inputsFrom = [cfg.devShell];
    config.canivete.just.recipes = {
      list = "@just --list";
      "changelog *ARGS" = "${getExe pkgs.convco} changelog --prefix \"\" {{ ARGS }}";
      "flake *ARGS" = "nix flake show {{ ARGS }}";
    };
  };
}
