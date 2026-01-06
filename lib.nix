lib: let
  inherit (lib) types;

  # -- dotship.lib.trivial
  trivial = {
    get = obj: attr: obj.${attr};
    pipe' = lib.flip lib.pipe;
    evalWith = arg: fun: fun arg;
    majorMinorVersion = trivial.pipe' [
      builtins.splitVersion
      (lib.sublist 0 2)
      (builtins.concatStringsSep ".")
      (builtins.replaceStrings ["."] [""])
    ];
    isNull = val: val == null;
    turnary = condition: yes: no:
      if condition
      then yes
      else no;
  };

  # -- dotship.lib.attrsets --
  attrsets = {
    isEmpty = attrs: attrs == {};
    mapNames = fun: lib.mapAttrs' (name: lib.nameValuePair (fun name));
    prefixNames = trivial.pipe' [lib.prefix lib.mapNames];
  };

  # -- dotship.lib.strings --
  strings = {
    first = builtins.substring 0 1;
    rest = str: builtins.substring 1 (builtins.stringLength str - 1) str;

    prefix = _prefix: str: lib.concatStrings [_prefix str];
    prefixJoin = _prefix: sep: lib.concatMapStringsSep sep (option: _prefix + option);

    pascalToCamel = str: lib.toLower (strings.first str) + strings.rest str;
    camelToPascal = str: lib.toUpper (strings.first str) + strings.rest str;

    # NOTE: taken from https://gist.github.com/manveru/74eb41d850bc146b7e78c4cb059507e2
    toBase64 = text: let
      convertTripletInt = let
        lookup = lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        pows = [(64 * 64 * 64) (64 * 64) 64 1];
        intSextets = i: map (j: lib.mod (i / j) 64) pows;
      in
        trivial.pipe' [intSextets (lib.concatMapStrings (builtins.elemAt lookup))];
      sliceToInt = builtins.foldl' (acc: val: acc * 256 + val) 0;
      nFullSlices = (builtins.stringLength text) / 3;
      tripletAt = let
        sliceN = size: list: n: lib.sublist (n * size) size list;
        bytes = map lib.strings.charToInt (lib.stringToCharacters text);
      in
        sliceN 3 bytes;

      first = let
        convertTriplet = trivial.pipe' [sliceToInt convertTripletInt];
      in
        builtins.genList (trivial.pipe' [tripletAt convertTriplet]) nFullSlices;
      rest = let
        convertLastSlice = slice: let
          len = builtins.length slice;
        in
          if len == 1
          then (builtins.substring 0 2 (convertTripletInt ((sliceToInt slice) * 256 * 256))) + "=="
          else if len == 2
          then (builtins.substring 0 3 (convertTripletInt ((sliceToInt slice) * 256))) + "="
          else "";
      in
        convertLastSlice (tripletAt nFullSlices);
    in
      builtins.concatStringsSep "" (first ++ [rest]);
  };

  # -- dotship.lib.filesets --
  filesets = rec {
    # DOC: List absolute path of files in <root> that satisfy <fun>
    _filter = fun: root:
      lib.pipe root [
        builtins.readDir
        (lib.filterAttrs fun)
        builtins.attrNames
        (map (file: root + "/${file}"))
      ];

    # DOC: Lists directories in <root>
    dirs = _filter (_: type: type == "directory");

    # DOC: Lists files in <root> that satisfy <fun>
    files = fun: _filter (name: type: type == "regular" && fun name type);

    # DOC: Recursively lists all files in <dirs> that satisfy <fun>
    everything = fun: let
      filesAndDirs = root:
        (files fun root) ++ (builtins.concatMap (everything fun) (dirs root));
    in
      lib.flip lib.pipe [
        lib.toList
        (map filesAndDirs)
        lib.flatten
      ];

    # DOC: Rejects <excluded> paths from "everything" in <roots> that satisfy <fun>
    everythingBut = fun: roots: excluded:
      _filter (_path: builtins.all (prefix: ! lib.path.hasPrefix prefix _path) excluded) (everything fun roots);

    # DOC: All of the previous functions (except for `dirs`) with a predefined filter for `nix` files
    nix = {
      filter = name: _: (builtins.match ".+\\.nix$" name != null) && (builtins.match ".*flake\\.nix$" name == null);
      files = files nix.filter;
      everything = everything nix.filter;
      everythingBut = everythingBut nix.filter;
    };
  };

  wrapped = wrapper: nested: rest: let
    option = type: description: rest: lib.mkOption ({inherit type description;} // rest);
    overlayDefault = _: _: {};

    # NOTE: Fixes nested option wrapping
    wrapOptions = value:
      if lib.isFunction value
      then arg: wrapOptions (value arg)
      else if builtins.isList value
      then map wrapOptions value
      else if builtins.isAttrs value
      then
        if (value._type or null) == "option" && (value ? type)
        then value // {type = wrapper value.type;}
        else builtins.mapAttrs (_: wrapOptions) value
      else value;
  in
    lib.pipe [
      # keep-sorted start
      "anything"
      "bool"
      "int"
      "lines"
      "package"
      "path"
      "pathInStore"
      "raw"
      "str"
      # keep-sorted end
    ] [
      (_types: lib.genAttrs _types lib.id)
      (lib.mergeAttrs {module = "deferredModule";})
      (builtins.mapAttrs (_: trivial.get types))
      (lib.mergeAttrs {
        overlay = types.mkOptionType {
          name = "overlays";
          description = "nixpkgs overlay";
          inherit (types.functionTo (types.functionTo (types.attrsOf types.anything))) check;
          merge = _: defs: builtins.foldl' (acc: fun: item: acc (fun item)) overlayDefault (map (item: item.value) defs);
        };

        # NOTE: `str` options with specific regex
        subdomain = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$";
        domain = types.strMatching "^([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-z]{2,10}$";
        email = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9_.%+\-]{0,61}[a-zA-Z0-9]@([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,10}$";
      })
      (builtins.mapAttrs (_: wrapper))
      (builtins.mapAttrs (_: option))
      # TODO: write these overrides more ergonomically!
      # TRACK: https://github.com/schradert/canivete/trunk/lib.nix#L187
      (builtins.mapAttrs (_: _option: description: _rest: _option description (rest // _rest)))
      (prev: let
        submoduleWith = args: module:
          types.submoduleWith {
            modules = [module];
            shorthandOnlyDefinesConfig = true;
            specialArgs = args // {inherit dotlib;};
          };

        attrTag = tags: types.attrTag tags;

        mkOption' = type: defaults: description: _rest:
          option (wrapper type) description (defaults // rest // _rest);
      in
        lib.mergeAttrs prev {
          # keep-sorted start
          attrTag = description: tags: mkOption' (attrTag tags) {default = {};} description {};
          enable = mkOption' types.bool {default = false;};
          enabled = mkOption' types.bool {default = true;};
          enum = values: mkOption' (types.enum values) {};
          flake = inputs: name: mkOption' (types.nullOr types.raw) {default = inputs.${name} or null;} name;
          module = description: _rest: prev.module description ({default = {};} // rest // _rest);
          option = type: mkOption' type {};
          overlay = description: _rest: prev.overlay description ({default = overlayDefault;} // rest // _rest);
          submodule = description: module: mkOption' (submoduleWith {} module) {default = {};} description {};
          submoduleWith = description: args: module: mkOption' (submoduleWith args module) {default = {};} description {};
          withSubmodule = module: lib.mkOption {type = wrapper (types.submodule module);};
          # keep-sorted end

          # keep-sorted start block=yes newline_separated=no
          toml = pkgs: mkOption' (pkgs.formats.toml {}).type {default = {};};
          yaml = pkgs: mkOption' (pkgs.formats.yaml {}).type {default = {};};
          # keep-sorted end
        })
      (lib.mergeAttrs (builtins.mapAttrs (_: trivial.pipe' [(trivial.evalWith attrs) wrapOptions]) nested))
    ];

  # DOC:
  #   wrapped nestable option types, e.g.:
  #     * `dotlib.options.attrs.str`             -> `types.attrsOf types.str`
  #     * `dotlib.options.nullable.attrs.str`    -> `types.nullOr (types.attrsOf types.str)`
  #     * `dotlib.options.function.str`          -> `types.functionTo types.str`
  #     * `dotlib.options.nullable.function.str` -> `types.nullOr (types.functionTo types.str)`
  #     * `dotlib.options.list.str`              -> `types.listOf types.str`
  #     * `dotlib.options.nullable.list.str`     -> `types.nullOr (types.listOf types.str)`

  # keep-sorted start
  attrs = wrapped types.nullOr {inherit attrs function list nullable;};
  function = wrapped types.functionTo {inherit attrs function list nullable;};
  list = wrapped types.listOf {inherit attrs function list nullable;};
  nullable = wrapped types.nullOr {inherit attrs function list;};
  # keep-sorted end

  # -- dotship.lib.options --
  options =
    (wrapped lib.id {} {})
    // {
      attrs = attrs {default = {};};
      function = function {};
      list = list {default = [];};
      nullable = nullable {default = null;};
    };

  # -- dotship.lib.options --
  vals = {
    sops.custom = config: file: attr: "ref+sops://${config.dotship.sops.directory}/${file}${attr}+";
    sops.default = config: attr: "ref+sops://${config.dotship.sops.default}#/${attr}+";
  };

  formats = {
    toml.generate = pkgs: (pkgs.formats.toml {}).generate;
    yaml.generate = pkgs: (pkgs.formats.yaml {}).generate;
  };

  dotlib = {
    inherit
      # keep-sorted start
      attrsets
      filesets
      formats
      options
      strings
      trivial
      vals
      # keep-sorted end
      ;
  };
in
  dotlib
