{nix, ...}:
with nix; {
  perSystem = {
    config,
    options,
    pkgs,
    self',
    system,
    ...
  }: let
    cfg = config.canivete.devShell;
  in {
    options.canivete.devShell = {
      name = mkOption {
        type = str;
        default = "can";
        description = "Name of the primary project executable";
      };
      apps = mkOption {
        type = attrsOf (submodule ({
          config,
          name,
          ...
        }: {
          options.dependencies = mkOption {
            type = listOf package;
            default = [];
          };
          options.script = mkOption {
            type = coercedTo str (script:
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = config.dependencies;
                excludeShellChecks = ["SC1091"];
                text = "source ${./utils.sh} && ${script}";
              })
            package;
          };
          config.dependencies = with pkgs; [bash coreutils git];
        }));
        default = {};
        description = "Subcommands for primary executable";
      };
      packages = mkOption {
        type = listOf package;
        default = [];
        description = "Packages to include in development shell";
      };
      shells = mkOption {
        type = listOf package;
        default = attrValues (removeAttrs self'.devShells ["default"]);
        description = "Development shells to include in the default";
      };
      inputsFrom = options.canivete.devShell.shells // {default = config.canivete.devShell.shells;};
    };
    config = {
      canivete.devShell = {
        packages = [pkgs.sops (with config.canivete.devShell; apps.${name}.script)];
        apps.help.script = "nix flake show";
        apps.${config.canivete.devShell.name}.script = "nix run \".#canivete.${system}.devShell.apps.\${1:-help}.script\" -- \"\${@:2}\"";
      };
      devShells.default = pkgs.mkShell {inherit (cfg) name packages inputsFrom;};
    };
  };
}
