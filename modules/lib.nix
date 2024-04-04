{
  config,
  lib,
  options,
  ...
}:
with lib; {
  options.canivete.lib = mkOption {type = with types; lazyAttrsOf anything;};
  options.flake.lib = options.canivete.lib;
  config = {
    canivete.lib = fold recursiveUpdate {} [
      builtins
      lib
      {
        mkMergeTopLevel = names:
          flip pipe [
            (foldAttrs (this: those: [this] ++ those) [])
            (mapAttrs (_: mkMerge))
            (getAttrs names)
          ];
        mkApp = program: {
          inherit program;
          type = "app";
        };
        mkIfElse = condition: yes: no:
          mkMerge [
            (mkIf condition yes)
            (mkIf (!condition) no)
          ];
      }
    ];
    flake.lib = config.canivete.lib;
    perSystem = {pkgs, ...}: {
      packages.canivete-utils = pkgs.writeShellScript "utils.sh" (readFile ./utils.sh);
    };
  };
}
