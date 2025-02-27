{inputs, ...}: {
  perSystem = perSystem @ {
    canivete,
    lib,
    pkgs,
    system,
    ...
  }: let
    inherit (canivete) mkModulesOption prefixAttrNames mkEnabledOption;
    inherit (lib) attrValues mkMerge getExe mkOption types mkIf mkEnableOption filter forEach concatStringsSep concatMap toJSON listToAttrs;
    inherit (types) attrsOf submodule raw str package anything;
    composition = cluster:
      mkOption {
        type = raw;
        description = "Evaluated kubenix composition for cluster";
        default = inputs.kubenix.evalModules.${system} {
          specialArgs = {inherit canivete;};
          module = {
            config,
            kubenix,
            pkgs,
            lib,
            ...
          }: {
            imports = with kubenix.modules; [k8s helm] ++ (attrValues cluster.modules);
            kubernetes.customTypes = let
              # Extract CustomResourceDefinitions from all modules
              crds = let
                CRDs = let
                  evaluation = inputs.kubenix.evalModules.${system} {
                    specialArgs = {inherit canivete;};
                    module = {kubenix, ...}: {
                      imports = with kubenix.modules; [k8s helm] ++ (attrValues cluster.modules);
                      options.kubernetes.api = mkOption {
                        type = submodule {freeformType = attrsOf anything;};
                      };
                    };
                  };
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
                generated = import "${inputs.kubenix}/pkgs/generators/k8s" {
                  name = "kubenix-generated-for-crds";
                  inherit pkgs lib;
                  # Mirror K8s OpenAPI spec
                  spec = toString (pkgs.writeTextFile {
                    name = "generated-kubenix-crds-schema.json";
                    text = toJSON {
                      definitions = listToAttrs (forEach crds (crd: {
                        name = crd.fqdn;
                        value = crd.schema;
                      }));
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
            in
              mkIf cluster.ifd (forEach crds (crd: {
                inherit (crd) group version kind attrName;
                module = submodule definitions."${crd.fqdn}";
              }));
          };
        };
      };
  in {
    options.canivete.kubenix = {
      enable = mkEnableOption "kubenix package builds" // {default = inputs ? kubenix;};
      sharedModules = canivete.mkModulesOption {};
      script = mkOption {
        type = package;
        default = pkgs.writeShellApplication {
          name = "kubenix";
          text = "nix run \".#canivete.${system}.kubenix.clusters.$1.script\" -- \"\${@:2}\"";
        };
      };
      clusters = mkOption {
        type = attrsOf (submodule ({
          config,
          name,
          ...
        }: let
          cluster = config;
        in {
          options = {
            ifd = mkEnabledOption "IFD to support custom types";
            deploy = {
              k3d = mkEnableOption "Deploy cluster locally with k3d";
              fetchKubeconfig = mkOption {
                type = str;
                description = "Script to fetch the kubeconfig of an externally managed Kubernetes cluster. Stdout is the contents of the file";
              };
            };
            opentofuWorkspace = mkOption {
              type = str;
              description = "OpenTofu workspace to include the config in";
              default = "deploy";
            };
            configuration = mkOption {
              type = package;
              description = "Kubernetes configuration file for cluster";
              default = cluster.composition.config.kubernetes.resultYAML;
            };
            script = mkOption {
              type = package;
              description = "Wrapper script";
              default = pkgs.writeShellApplication {
                inherit name;
                text = ''
                  # Vals needs to run in project root to access sops config
                  cd "$(${getExe pkgs.git} rev-parse --show-toplevel)"

                  # Connect to cluster
                  KUBECONFIG="$(mktemp)"
                  export KUBECONFIG
                  trap 'rm -f "$KUBECONFIG"' EXIT
                  ${cluster.deploy.fetchKubeconfig} >"$KUBECONFIG"

                  nix build .#canivete.${system}.kubenix.clusters.${name}.configuration --no-link --print-out-paths | \
                    xargs cat | \
                    ${getExe pkgs.vals} eval -s -f - | \
                    ${getExe pkgs.yq} "." --yaml-output | \
                    ${getExe pkgs.bash} -c "$@"
                '';
              };
            };
            modules = mkModulesOption {};
            composition = composition cluster;
          };
          config = mkMerge [
            {modules = prefixAttrNames "shared-" perSystem.config.canivete.kubenix.sharedModules;}
            (mkIf cluster.deploy.k3d {deploy.fetchKubeconfig = "${getExe pkgs.k3d} kubeconfig get ${name}";})
          ];
        }));
        default = {};
        description = "Kubernetes clusters";
      };
    };
  };
}
