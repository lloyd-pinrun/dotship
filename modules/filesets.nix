{
  config,
  lib,
  ...
}:
with lib; {
  options.canivete.filesets.lib = mkOption {type = with types; attrsOf anything;};
  config.canivete.filesets.lib.filesets = rec {
    # List absolute path of files in <root> that satisfy <f>
    filter = f: root:
      trivial.pipe root [
        builtins.readDir
        (attrsets.filterAttrs f)
        builtins.attrNames
        (builtins.map (file: root + "/${file}"))
      ];
    # List directories in <root>
    dirs = filter (_: type: type == "directory");
    # List files in <root> that satisfy <f>
    files = f: filter (name: type: type == "regular" && f name type);
    # Recursively list all files in <_dirs> that satisfy <f>
    everything = f: _dirs: let
      filesAndDirs = root: [
        (files f root)
        (builtins.map (everything f) (dirs root))
      ];
    in
      trivial.pipe _dirs [lists.toList (builtins.map filesAndDirs) lists.flatten];
    # Filter out <exclude> paths from "everything" in <roots>
    everythingBut = f: roots: exclude: builtins.filter (_path: builtins.all (prefix: ! path.hasPrefix prefix _path) exclude) (everything f roots);
    nix = {
      filter = name: _: builtins.match ".+\.nix$" name != null;
      files = files nix.filter;
      everything = everything nix.filter;
      everythingBut = everythingBut nix.filter;
    };
  };
}
