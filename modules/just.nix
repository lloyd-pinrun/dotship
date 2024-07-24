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
        type = attrsOf (coercedTo str (setAttrByPath "command") (submodule ({
          config,
          name,
          ...
        }: {
          enable = mkEnabledOption name;
          command = mkOption {
            type = str;
            description = "Actual command to run as part of this unique recipe";
          };
          recipe = mkOption {
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
      justfile = mkOption {
        type = package;
        description = "Justfile with recipe commands";
        default = pipe cfg.recipes [
          (filterAttrs (_: getAttr "enable"))
          (mapAttrsToList (_: getAttr "recipe"))
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
    };
    config.devShells.just = pkgs.mkShell {packages = [cfg.finalPackage];};
    config.canivete.just.recipes = {
      default = "@just --list";
      changelog = "${getExe pkgs.convco} changelog -p \"\"";
    };
  };
}
