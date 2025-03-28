base: let
  # TODO why wasn't this possible with extendModules inside module args? reached max-call-depth
  default = let
    module = {canivete, config, lib, options, ...}: {
      config.kubernetes.customTypes = config.canivete.ifd.crds;
      options.canivete.ifd = {
        enable = canivete.mkEnabledOption "IFD to support custom types";
        crds = lib.mkOption {
          # TODO why is this not possible to achieve automatically?
          type = let
            inherit (builtins) elemAt mapAttrs;
            inherit (lib.types) attrsOf coercedTo str;
            parse = attrName: type: let
              values = lib.splitString "/" type;
            in {
              inherit attrName;
              group = elemAt values 0;
              version = elemAt values 1;
              kind = elemAt values 2;
            };
          in coercedTo (attrsOf str) (mapAttrs parse) options.kubernetes.customTypes.type;
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
      inherit (builtins) concatMap filter listToAttrs;
      inherit (lib) concatStringsSep forEach mkIf mkOption nameValuePair types;
      inherit (types) attrsOf anything submodule;

      # Extract CustomResourceDefinitions from all modules
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

      # Generate resource definitions with IFD x 2
      definitions = let
        generated = import "${flake.inputs.kubenix}/pkgs/generators/k8s" {
          name = "kubenix-generated-for-crds";
          inherit pkgs lib;
          # Mirror K8s OpenAPI spec
          spec = toString (pkgs.writeTextFile {
            name = "generated-kubenix-crds-schema.json";
            text = builtins.toJSON {
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
      kubernetes.customTypes = listToAttrs (forEach crds (crd: nameValuePair crd.attrName {
        inherit (crd) group version kind attrName;
        module = types.submodule definitions.${crd.fqdn};
      }));
    };
  in
    default.extendModules {modules = [module];};
  result =
    if default.config.canivete.ifd.enable
    then ifd
    else default;
in
  result
