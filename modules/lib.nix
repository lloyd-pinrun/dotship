{lib, ...}:
with lib; {
  options.flake.lib = mkOption {type = with types; lazyAttrsOf anything;};
  config.flake.lib = fold recursiveUpdate {} [
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
  config.perSystem = {pkgs, ...}: {
    packages.canivete-utils = pkgs.writeShellScript "utils.sh" (readFile ./utils.sh);
  };
}
