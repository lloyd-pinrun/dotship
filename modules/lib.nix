{
  inputs,
  config,
  lib,
  options,
  ...
}:
with lib; {
  options = {
    canivete.lib = mkOption {type = with types; lazyAttrsOf anything;};
    flake.lib = options.canivete.lib;
  };
  config = {
    flake.lib = config.canivete.lib;
    canivete.lib = with builtins;
      builtins
      // lib
      // rec {
        # Utilities egregiously omitted from nixpkgs lib
        pipe' = flip trivial.pipe;
        removeAttrs' = flip removeAttrs;
        mapAttrsToList' = flip attrsets.mapAttrsToList;
        recursiveUpdate' = flip attrsets.recursiveUpdate;
        attrVals' = flip attrsets.attrVals;
        keepAttrs' = attrset:
          config.pipe' [
            (map (attr: attrsets.nameValuePair attr attrset.${attr}))
            listToAttrs
          ];

        eval = arg: f: f arg;
        keepAttrs = flip config.keepAttrs';
        majorMinorVersion = pipe' [splitVersion (sublist 0 2) (concatStringsSep ".") (replaceStrings ["."] [""])];

        mkIfElse = condition: yes: no:
          mkMerge [
            (mkIf condition yes)
            (mkIf (!condition) no)
          ];
        mkApp = program: {
          inherit program;
          type = "app";
        };

        filesets = rec {
          # List absolute path of files in <root> that satisfy <f>
          filter = f: root:
            trivial.pipe root [
              readDir
              (attrsets.filterAttrs f)
              attrNames
              (map (file: root + "/${file}"))
            ];
          # List directories in <root>
          dirs = filter (_: type: type == "directory");
          # List files in <root> that satisfy <f>
          files = f: filter (name: type: type == "regular" && f name type);
          # Recursively list all files in <_dirs> that satisfy <f>
          everything = f: _dirs: let
            filesAndDirs = root: [
              (files f root)
              (map (everything f) (dirs root))
            ];
          in
            trivial.pipe _dirs [lists.toList (map filesAndDirs) lists.flatten];
          # Filter out <exclude> paths from "everything" in <roots>
          everythingBut = f: roots: exclude: filter (_path: all (prefix: ! path.hasPrefix prefix _path) exclude) (everything f roots);
          nix = {
            filter = name: _: match ".+\.nix$" name != null;
            files = files nix.filter;
            everything = everything nix.filter;
            everythingBut = everythingBut nix.filter;
          };
        };
      };
  };
}
