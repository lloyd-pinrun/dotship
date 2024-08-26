{
  config,
  inputs,
  nix,
  ...
}:
with nix; {
  perSystem = perSystem @ {
    config,
    pkgs,
    system,
    ...
  }: let
    kubenix-patched = pkgs.applyPatches {
      name = "kubenix-patched-src";
      src = inputs.kubenix;
      patches = [./kubenix.patch];
    };
  in {
    config.packages.kubenix = pkgs.writeShellApplication {
      name = "kubenix";
      text = ''
        config="$(mktemp)"
        cat /dev/stdin >"$config"
        KUBECONFIG="$(mktemp)"
        export KUBECONFIG
        trap 'rm -f "$KUBECONFIG" "$config"' EXIT
        eval "$(nix eval ".#canivete.${system}.kubenix.clusters.$1.deploy.fetchKubeconfig" | tr -d "\"")" >"$KUBECONFIG"
        "''${@:2}" <"$config"
      '';
    };
    config.canivete = {
      opentofu.workspaces = pipe config.canivete.kubenix.clusters [
        (mapAttrsToList (name: cfg: {
          ${cfg.opentofuWorkspace} = mkMerge [
            {
              plugins = ["opentofu/null"];
              modules.kubenix.resource.null_resource.kubernetes = {
                triggers.drv = cfg.configuration.drvPath;
                provisioner.local-exec.command = ''
                  set -euo pipefail
                  # Vals needs to run in project root to access sops config
                  cd "$(${getExe pkgs.git} rev-parse --show-toplevel)"
                  nix build .#canivete.${system}.kubenix.clusters.${name}.configuration --no-link --print-out-paths | \
                    xargs cat | \
                    ${getExe pkgs.vals} eval -s -f - | \
                    ${getExe pkgs.yq} "." --yaml-output | \
                    nix run .#kubenix -- ${name} ${pkgs.kubectl}/bin/kubectl apply --server-side --prune -f -
                '';
              };
            }
            (mkIf cfg.deploy.k3d {
              plugins = ["pvotal-tech/k3d"];
              modules.k3d.resource.k3d_cluster.main = {
                inherit name;
                servers = 1;
              };
            })
          ];
        }))
        mkMerge
      ];
      kubenix.sharedModules.defaults = {config, ...}: {
        options.kubernetes.helm.releases = mkOption {
          type = attrsOf (submodule ({config, ...}: {
            # 1. include CRDs in Helm chart releases
            includeCRDs = mkDefault true;
            namespace = mkDefault config.name;
            overrideNamespace = mkDefault false;
            overrides = toList {
              # 2. every resource gets this label to select by chart
              metadata.labels."canivete/chart" = config.name;
              # 3. set the namespace to the chart name
              metadata.namespace = mkDefault config.namespace;
            };
          }));
        };
        # 4. every resource gets a namespace label
        config.kubernetes.api.defaults = toList {
          default = {config, ...}: {
            metadata.labels."canivete/namespace" =
              if config.kind == "Namespace"
              then config.metadata.name
              else config.metadata.namespace;
          };
        };
      };
    };
    options.canivete.kubenix.sharedModules = mkModulesOption {};
    options.canivete.kubenix.clusters = mkOption {
      type = attrsOf (submodule ({
        config,
        name,
        ...
      }: let
        cluster = config;
      in {
        options = {
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
          modules = mkModulesOption {};
          composition = mkOption {
            type = raw;
            description = "Evaluated kubenix composition for cluster";
            default = kubenix-patched.evalModules.${system} {
              specialArgs = {inherit nix;};
              module = {
                config,
                kubenix,
                pkgs,
                lib,
                ...
              }: {
                imports = with kubenix.modules; [k8s helm] ++ attrValues cluster.modules;
                kubernetes.customTypes = let
                  # Extract CustomResourceDefinitions from all modules
                  crds = let
                    CRDs = let
                      evaluation = kubenix-patched.evalModules.${system} {
                        specialArgs = {inherit nix;};
                        module = {kubenix, ...}: {
                          imports = with kubenix.modules; [k8s helm] ++ attrValues cluster.modules;
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
                    generated = import "${kubenix-patched}/pkgs/generators/k8s" {
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
                  forEach crds (crd: {
                    inherit (crd) group version kind attrName;
                    module = submodule definitions."${crd.fqdn}";
                  });
              };
            };
          };
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
}
