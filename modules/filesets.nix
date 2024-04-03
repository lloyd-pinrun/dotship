{lib, ...}:
with lib; {
  options.canivete.filesets = mkOption {type = with types; lazyAttrsOf anything;};
  config.canivete.filesets = rec {
    # List absolute path of files in <root> that satisfy <f>
    filter = f: root:
      pipe root [
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
    everything = f: let
      filesAndDirs = root: [
        (files f root)
        (map (everything f) (dirs root))
      ];
    in
      flip pipe [lists.toList (map filesAndDirs) lists.flatten];
    # Filter out <exclude> paths from "everything" in <roots>
    everythingBut = f: roots: exclude: filter (_path: all (prefix: ! path.hasPrefix prefix _path) exclude) (everything f roots);
    nix = {
      filter = name: _: match ".+\.nix$" name != null;
      files = files nix.filter;
      everything = everything nix.filter;
      everythingBut = everythingBut nix.filter;
    };
  };
}
