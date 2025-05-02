base: let
  default = let
    module = {
      dotship,
      config,
      lib,
      options,
      ...
    }: let
      inherit (builtins) elemAt mapAttrs;

      inherit
        (lib)
        mkEnableOption
        mkOption
        splitString
        types
        ;
    in {
      config.kubernetes.customTypes = config.dotship.ifd.crds;
      options.dotship.ifd = {
        enable = mkEnableOption "IFD to support custom types" // {default = true;};
        crds = mkOption {
          type = let
            parse = attrName: type: let
              values = splitString "/" type;
            in {
              inherit attrName;

              group = elemAt values 0;
              version = elemAt values 1;
              kind = elemAt values 2;
            };
          in
            types.coercedTo (types.attsOf types.str) (mapAttrs parse) options.kubernetes.customTypes.types;
          default = {};
          description = "CRDs to support IFD (one string per CRD)";
        };
      };
    };
  in
    base.extendModules {modules = [module];};

  ifd = let
    module = {
      config,
      flake,
      lib,
      pkgs,
      ...
    }: let
      inherit
        (builtins)
        concatMap
        filter
        listToAttrs
        toJSON
        toString
        ;

      inherit
        (lib)
        concatStringsSep
        forEach
        nameValuePair
        types
        ;

      crds = let
        CRDs = filter (object: object.kind == "CustomResourceDefinition") default.config.kubernetes.objects;
        CRD2crd = CRD:
          forEach CRD.spec.versions (_version: rec {
            inherit (CRD.spec) group;
            inherit (CRD.spec.names) kind;

            version = _version.name;
            attrName = CRD.spec.names.plural;
            fqdn = concatStringsSep "." [group version kind];
            schema = _version.schema.openAPIV3Schema;
          });
      in
        concatMap CRD2crd CRDs;

      definitions = let
        generated = import (flake.inputs.kubenix + "/pkgs/generators/k8s") {
          inherit pkgs lib;

          name = "kubenix-generated-for-crds";
          spec = toString (pkgs.writeTextFile {
            name = "generated-kubenix-crds-schema.json";
            text = toJSON {
              definitions = listToAttrs (forEach crds (crd: nameValuePair crd.fqdn crd.schema));
              paths = {};
            };
          });
        };

        evaluation = import "${generated}" {
          inherit config lib;
          options = null;
        };
      in
        evaluation.config.definitions;
    in {
      kubernetes.customTypes = listToAttrs (forEach crds (
        crd:
          nameValuePair crd.attrName {
            inherit (crd) group version kind attrName;
            module = types.submodule definitions.${crd.fqdn};
          }
      ));
    };
  in
    default.extendedModules {modules = [module];};

  result =
    if default.config.dotship.ifd.enable
    then ifd
    else default;
in
  result
