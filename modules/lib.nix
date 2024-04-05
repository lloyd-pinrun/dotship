{
  config,
  inputs,
  lib,
  options,
  ...
}:
with lib; {
  options.canivete.lib = mkOption {type = with types; lazyAttrsOf anything;};
  options.flake.lib = options.canivete.lib;
  config = {
    perSystem = {pkgs, ...}: {
      packages.canivete-utils = pkgs.writeShellScript "utils.sh" (readFile ./utils.sh);
    };
    flake.lib = config.canivete.lib;
    canivete.lib = fold recursiveUpdate {} [
      builtins
      lib
      {
        # Fileset collectors
        filesets = rec {
          # List absolute path of files in <root> that satisfy <f>
          filter = f: root:
            pipe root [
              builtins.readDir
              (attrsets.filterAttrs f)
              attrNames
              (map (file: root + "/${file}"))
            ];
          # List directories in <root>
          dirs = filter (_: type: type == "directory");
          # List files in <root> that satisfy <f>
          files = f: filter (name: type: type == "regular" && f name type);
          # Recursively list all files in <_dirs> that satisfy <f>
          everything = f: let
            filesAndDirs = root: [
              (files f root)
              (map (everything f) (dirs root))
            ];
          in
            flip pipe [toList (map filesAndDirs) flatten];
          # Filter out <exclude> paths from "everything" in <roots>
          everythingBut = f: roots: exclude: filter (_path: all (prefix: ! path.hasPrefix prefix _path) exclude) (everything f roots);
          nix = {
            filter = name: _: builtins.match ".+\.nix$" name != null;
            files = files nix.filter;
            everything = everything nix.filter;
            everythingBut = everythingBut nix.filter;
          };
        };
      }
      rec {
        # Common options
        mkOverrideOption = args: pipe' [(trivial.mergeAttrs args) mkOption];
        mkEnabledOption = doc:
          mkOption {
            type = types.bool;
            default = true;
            example = false;
            description = mdDoc "Whether to enable ${doc}";
          };
        mkModulesOption = mkOverrideOption {
          type = with types; attrsOf deferredModule;
          default = {};
        };
        mkSystemOption = args: mkOption ({type = types.enum (import inputs.systems);} // args);
      }
      {
        # Convenience utilities
        flatMap = f: flip pipe [(map f) flatten];
        mkApp = program: {
          inherit program;
          type = "app";
        };
        mkIfElse = condition: yes: no:
          mkMerge [
            (mkIf condition yes)
            (mkIf (!condition) no)
          ];
        mkMergeTopLevel = names:
          flip pipe [
            (foldAttrs (this: those: [this] ++ those) [])
            (mapAttrs (_: mkMerge))
            (getAttrs names)
          ];
      }
    ];
  };
}
