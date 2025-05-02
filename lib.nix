{
  config,
  inputs,
  lib,
}: let
  inherit
    (builtins)
    functionArgs
    match
    readDir
    removeAttrs
    substring
    stringLength
    ;

  inherit
    (lib)
    attrNames
    concat
    concatMapStringsSep
    concatStrings
    filterAttrs
    flatten
    flip
    foldAttrs
    getAttrs
    hasPrefix
    id
    literalExpression
    mapAttrs
    mapAttrs'
    mergeAttrs
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optionalAttrs
    pipe
    toList
    toLower
    toUpper
    ;

  inherit
    (lib.types)
    anything
    bool
    deferredModule
    enum
    lazyAttrsOf
    listOf
    nullOr
    raw
    str
    strMatching
    submodule
    ;
in rec {
  attrsets = rec {
    mapAttrNames = fn: mapAttrs' (name: nameValuePair (fn name));
    prefixAttrNames = flip pipe [strings.prefix mapAttrNames];
  };

  filesets = rec {
    filter = fn: root:
      pipe root [
        readDir
        (filterAttrs fn)
        attrNames
        (map (file: root + "/${file}"))
      ];

    directories = filter (_: type: type == "directory");
    files = fn: filter (name: type: type == "regular" && fn name type);

    all = fn: let
      filesAndDirectories = root: [
        (files fn root)
        (map (all fn) (directories root))
      ];
    in
      flip pipe [toList (map filesAndDirectories) flatten];

    reject = fn: roots: exclude:
      filter (path: all (prefix: ! hasPrefix prefix path) exclude) (all fn roots);

    nix = {
      filter = name: _: match ".+/nix$" name != null;
      files = files nix.filter;
      all = all nix.filter;
      reject = reject nix.filter;
    };
  };

  functions = rec {
    defaultArgs = flip pipe [functionArgs (filterAttrs (_: id)) attrNames];
    nonDefaultArgs = fn: removeAttrs (functionArgs fn) (defaultArgs fn);
    evalWith = arg: fn: fn arg;
  };

  lists.flatMap = list: flip pipe [(map list) flatten];

  options = rec {
    mkOverrideOption = args: flip pipe [(mergeAttrs args) mkOption];

    mkNullableOption = type:
      mkOverrideOption {
        type = nullOr type;
        default = null;
      };

    mkArgsOption = mkOverrideOption {
      type = listOf str;
      default = [];
    };

    mkDisabledOption = doc:
      mkOption {
        type = bool;
        default = false;
        example = literalExpression "true";
        description = "Whether to enable ${doc}";
      };

    mkEnabledOption = doc:
      mkOption {
        type = bool;
        default = true;
        example = literalExpression "false";
        description = "Whether to enable ${doc}";
      };

    mkModulesOption = mkOverrideOption {
      type = lazyAttrsOf deferredModule;
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

    mkFlakeOption = name:
      mkOverrideOption {
        type = nullOr raw;
        default = inputs.${name} or null;
      };

    mkListOption = type:
      mkOverrideOption {
        type = listOf type;
        default = [];
      };

    mkSubdomainOption = mkOverrideOption {
      type = types.subDomain;
      example = literalExpression ''
        "my-TEST-subdomain1"
      '';
    };

    mkDomainOption = mkOverrideOption {
      type = types.domain;
      example = literalExpression ''
        "something.like.this";
      '';
    };

    mkEmailOption = mkOverrideOption {
      type = types.email;
      example = literalExpression ''
        "my_email-address+%@something.like.this"
      '';
    };

    mkLatestVersionOption = mkOverrideOption {
      type = str;
      default = "latest";
      example = literalExpression "\"0.0.1\"";
      description = "Set the version. Defaults to null (i.e. latest)";
    };

    mkFunctionArgsOption = fn:
      mkOverrideOption {
        type = submodule {
          options = flip mapAttrs (functionArgs fn) (
            _: hasDefault:
              mkOption ({type = anything;} // optionalAttrs hasDefault {default = null;})
          );
        };
      };
  };

  strings = rec {
    head = str: substring 0 1 str;
    tail = str: substring 1 (stringLength str - 1) str;

    prefix = prefix: str: concatStrings [prefix str];
    prefixJoin = prefix: sep: concatMapStringsSep sep (option: (prefix + option));

    camelCase = str: prefix (toLower (head str)) (tail str);
    PascalCase = str: prefix (toUpper (head str)) (tail str);
  };

  trivial.turnary = condition: yes: no:
    if condition
    then yes
    else no;

  types = {
    email = strMatching "^[a-zA-Z0-9][a-zA-Z0-9_.%+\-]{0,61}[a-zA-Z0-9]@([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,10}$";
    domain = strMatching "^([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-z]{2,10}$";
    subDomain = strMatching "^[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$";
  };

  mkApp = program: {
    inherit program;
    type = "app";
  };

  mkTurnary = condition: yes: no:
    mkMerge [
      (mkIf condition yes)
      (mkIf (!condition) no)
    ];

  mkUnless = condition: mkIf (!condition);

  # NOTE: borroed from https://gist.github.com/udf/4d9301bdc02ab38439fd64fbda06ea43
  mkMergeToplevel = names:
    flip pipe [
      (foldAttrs (this: those: [this] ++ those) [])
      (mapAttrs (_: mkMerge))
      (getAttrs names)
    ];

  mkFlake = args: all: module:
    inputs.flake-parts.lib.mkFlake {inputs = inputs // args.inputs;} {
      imports = concat [module ./.] (filesets.nix.all all);
    };
}
