{
  canivete,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config._module.args.canivete) functions prefix mapAttrNames mkOverrideOption filesets;
  inherit (builtins) functionArgs;
  inherit (lib) attrsets lists path strings trivial versions options types modules;
  inherit (attrsets) filterAttrs attrNames mapAttrs' nameValuePair foldAttrs mapAttrs getAttrs optionalAttrs;
  inherit (lists) all flatten sublist toList;
  inherit (modules) mkMerge mkIf;
  inherit (options) mkOption;
  inherit (strings) concatMapStringsSep substring replaceStrings stringLength concatStrings concatStringsSep toLower toUpper;
  inherit (trivial) concat flip pipe id mergeAttrs;
  inherit (types) attrsOf deferredModule enum listOf nullOr raw str;
  inherit (versions) splitVersion;
in {
  perSystem._module.args.canivete = canivete;
  _module.args.canivete = {
    # Fileset collectors
    filesets = rec {
      # List absolute path of files in <root> that satisfy <f>
      filter = f: root:
        pipe root [
          builtins.readDir
          (filterAttrs f)
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

    # Useful functions
    evalWith = arg: f: f arg;
    majorMinorVersion = flip pipe [splitVersion (sublist 0 2) (concatStringsSep ".") (replaceStrings ["."] [""])];
    functions.defaultArgs = flip pipe [
      functionArgs
      (filterAttrs (_: id))
      attrNames
    ];
    functions.nonDefaultArgs = f: removeAttrs (functionArgs f) (functions.defaultArgs f);
    ifElse = condition: yes: no:
      if condition
      then yes
      else no;
    mapAttrNames = f: mapAttrs' (name: nameValuePair (f name));
    prefixAttrNames = flip pipe [prefix mapAttrNames];

    # String manipulation
    prefix = pre: str: concatStrings [pre str];
    prefixJoin = prefix: separator: concatMapStringsSep separator (option: "${prefix}${option}");
    pascalToCamel = str: let
      first = substring 0 1 str;
      rest = substring 1 (stringLength str - 1) str;
    in
      toLower first + rest;
    camelToPascal = str: let
      first = substring 0 1 str;
      rest = substring 1 (stringLength str - 1) str;
    in
      toUpper first + rest;

    # Common options
    mkOverrideOption = args: flip pipe [(mergeAttrs args) mkOption];
    mkNullableOption = type: mkOverrideOption {
      type = nullOr type;
      default = null;
    };
    mkArgsOption = mkOverrideOption {
      type = listOf str;
      default = [];
    };
    mkEnabledOption = doc:
      mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = "Whether to enable ${doc}";
      };
    mkModulesOption = mkOverrideOption {
      type = attrsOf deferredModule;
      default = {};
    };
    mkModuleOption = mkOverrideOption {
      type = deferredModule;
      default = {};
    };
    mkSystemOption = mkOverrideOption {
      type = enum config.systems;
      description = "System for package builds";
    };
    mkFlakeOption = name: mkOverrideOption {
      type = raw;
      default = inputs.${name};
    };
    mkSubdomainOption = mkOverrideOption {
      type = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$";
      example = "my-TEST-subdomain1";
    };
    mkDomainOption = mkOverrideOption {
      type = types.strMatching "^([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-z]{2,10}$";
      example = "something.like.this";
    };
    mkEmailOption = mkOverrideOption {
      type = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9_.%+\-]{0,61}[a-zA-Z0-9]@([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,10}$";
      example = "my_email-address+%@something.like.this";
    };
    mkLatestVersionOption = mkOverrideOption {
      type = types.str;
      default = "latest";
      example = "0.0.1";
      description = "Set the version. Defaults to null (i.e. latest)";
    };
    mkFunctionArgsOption = func: mkOverrideOption {
      type = types.submodule {
        options = flip mapAttrs (functionArgs func) (_: hasDefault:
          mkOption ({type = types.anything;} // optionalAttrs hasDefault {default = null;})
        );
      };
    };

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
    mkUnless = condition: mkIf (!condition);
    mkMergeTopLevel = names:
      flip pipe [
        (foldAttrs (this: those: [this] ++ those) [])
        (mapAttrs (_: mkMerge))
        (getAttrs names)
      ];

    # Create a flake-parts flake with everything imported
    mkFlake = args: everything: module:
      inputs.flake-parts.lib.mkFlake {inputs = inputs // args.inputs;} {
        imports = concat [module ./.] (filesets.nix.everything everything);
      };

    # Vals shorthand
    vals.sops = attr: "ref+sops://.canivete/sops/${attr}+";
    vals.tfstate = workspace: attr: "ref+tfstate://.canivete/opentofu/${workspace}/terraform.tfstate.dec/${attr}+";
  };
}
