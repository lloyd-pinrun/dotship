{lib, ...}:
with lib; {
  options.flake.lib = mkOption {type = with types; lazyAttrsOf anything;};
  config.flake.lib = mkMerge [
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
    }
  ];
  config.perSystem = {pkgs, ...}: {
    packages.canivete-utils = pkgs.writeShellScript "utils.sh" (readFile ./utils.sh);
  };
}
