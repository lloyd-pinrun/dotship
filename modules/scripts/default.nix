{nix, ...}:
with nix; {
  perSystem = {pkgs, ...}: {
    options.canivete.scripts = mkOption {
      type = attrsOf (coercedTo pathInStore (setAttrByPath ["script"]) (submodule ({
        config,
        name,
        ...
      }: {
        options = {
          script = mkOption {
            type = pathInStore;
            description = "Base script to wrap into executable";
          };
          package = mkOption {
            type = package;
            description = "Actual executable to run directly";
            default = pkgs.writeShellApplication {
              inherit name;
              runtimeInputs = with pkgs; [bash coreutils git];
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
