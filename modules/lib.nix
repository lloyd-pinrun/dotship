flake @ {lib, ...}: {
  options.canivete.lib = with lib;
  with types; {
    lib = mkOption {
      default = {};
      type = submoduleWith {
        modules = [
          {freeformType = lazyAttrsOf anything;}
          {config = builtins.removeAttrs lib ["nixpkgsVersion" "zip" "zipWithNames"];}
          {config = builtins;}
          # Utilities egregiously omitted from nixpkgs lib
          ({config, ...}: {
            config = {
              pipe' = flip trivial.pipe;
              removeAttrs' = flip builtins.removeAttrs;
              mapAttrsToList' = flip attrsets.mapAttrsToList;
              recursiveUpdate' = flip attrsets.recursiveUpdate;
              attrVals' = flip attrsets.attrVals;
              keepAttrs' = attrset:
                config.pipe' [
                  (map (attr: attrsets.nameValuePair attr attrset.${attr}))
                  builtins.listToAttrs
                ];

              eval = arg: f: f arg;
              keepAttrs = flip config.keepAttrs';
              majorMinorVersion = pipe' [splitVersion (sublist 0 2) (concatStringsSep ".") (replaceStrings ["."] [""])];
            };
          })
          # ({config, ...}: {
          #   config = trivial.pipe lib [
          #     (config.keepAttrs' flake.config.canivete.lib.flattenedNamespaces)
          #     builtins.attrValues
          #     mkMerge
          #   ];
          # })
        ];
      };
    };
    # flattenedNamespaces = mkOption {
    #   type = trivial.pipe lib [
    #     (attrsets.filterAttrs (_: builtins.isAttrs))
    #     builtins.attrNames
    #     types.enum
    #     types.listOf
    #   ];
    #   default = ["trivial" "strings" "lists" "attrsets"];
    # };
  };
  config.flake.lib = flake.config.canivete.lib.lib;
}
