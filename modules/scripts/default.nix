{nix, ...}:
with nix; {
  perSystem = {pkgs, ...}: {
    config.canivete.devShell.shellHooks = ["source ${./utils.sh}"];
    options.canivete.scripts = mkOption {
      type = attrsOf (coercedTo pathInStore (setAttrByPath ["script"]) (submodule ({
        config,
        name,
        ...
      }: {
        config.runtimeInputs = with pkgs; [bash coreutils git];
        config.excludeShellChecks = ["SC1091"];
        options = {
          script = mkOption {
            type = pathInStore;
            description = "Base script to wrap into executable";
          };
          excludeShellChecks = mkOption {
            type = listOf str;
            description = "ShellCheck rules to disable";
            default = [];
          };
          runtimeInputs = mkOption {
            type = listOf package;
            description = "Runtime dependencies";
            default = [];
          };
          package = mkOption {
            type = package;
            description = "Actual executable to run directly";
            default = pkgs.writeShellApplication {
              inherit name;
              inherit (config) runtimeInputs excludeShellChecks;
              text = ''
                source ${./utils.sh}
                ${readFile config.script}
              '';
            };
          };
        };
      })));
      description = "Complicated repository scripts";
      default = {};
    };
  };
}
