base: let
  # TODO why wasn't this possible with extendModules inside module args? reached max-call-depth
  default = let
    module = {canivete, ...}: {options.canivete.ifd = canivete.mkEnabledOption "IFD to support custom types";};
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
      inherit (lib) concatMap concatStringsSep filter forEach listToAttrs mkIf mkOption nameValuePair toJSON types;
      inherit (types) attrsOf anything submodule;

      # Extract CustomResourceDefinitions from all modules
      crds = let
        CRDs = let
          overrideModule = {options.kubernetes.api = mkOption {type = submodule {freeformType = attrsOf anything;};};};
          evaluation = default.extendModules {modules = [overrideModule];};
        in
          filter (object: object.kind == "CustomResourceDefinition") evaluation.config.kubernetes.objects;
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
      config = mkIf config.canivete.ifd {
        kubernetes.customTypes = forEach crds (crd: {
          inherit (crd) group version kind attrName;
          module = submodule definitions."${crd.fqdn}";
        });
      };
    };
  in
    default.extendModules {modules = [module];};
  result =
    if default.config.canivete.ifd
    then ifd
    else default;
in
  result
