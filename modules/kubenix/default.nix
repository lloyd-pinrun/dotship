{
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
    config.canivete = {
      scripts.kubectl = ./kubectl.sh;
      just.recipes."kubectl CLUSTER *ARGS" = ''
        nix run .#canivete.${system}.kubenix.clusters.{{ CLUSTER }}.finalScript -- -- {{ ARGS }}
      '';
      opentofu.workspaces = mkMerge (flip mapAttrsToList config.canivete.kubenix.clusters (_: cfg: nameValuePair cfg.opentofuWorkspace cfg.opentofu));
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
        # 4. create namespace for each release
        config.kubernetes.resources.namespaces = flip mapAttrs' config.kubernetes.helm.releases (name: release:
          nameValuePair release.namespace {
            metadata.labels."canivete/chart" = name;
          });
        # 5. every resource gets a namespace label
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
        bins = makeBinPath (with pkgs; [vals sops kubectl yq opentofu]);
        flags = concatStringsSep " " [
          "--cluster ${name}"
          "--config ${cluster.configuration}"
        ];
        args = "--prefix PATH : ${bins} --add-flags \"${flags}\"";
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
          opentofu = mkOption {
            # Can't use deferredModule here because it breaks merging with OpenTofu workspaces
            type = lazyAttrsOf anything;
            default = {};
            description = "OpenTofu workspace to deploy";
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
          configuration = mkOption {
            type = package;
            description = "Kubernetes configuration file for cluster";
            default = cluster.composition.config.kubernetes.resultYAML;
          };
          script = mkOption {
            type = package;
            description = "Kubectl wrapper script for managing cluster";
            default = pkgs.wrapProgram perSystem.config.canivete.scripts.kubectl.package "kubectl" "kubectl" args {};
          };
          scriptOverride = mkOption {
            type = functionTo package;
            description = "Function to map script to finalScript";
            default = id;
          };
          finalScript = mkOption {
            type = package;
            description = "Final script to run kubectl on the cluster configuration";
            default = cluster.scriptOverride cluster.script;
          };
        };
        config = mkMerge [
          {
            modules = prefixAttrNames "shared-" perSystem.config.canivete.kubenix.sharedModules;
          }
          {
            opentofu.plugins = ["opentofu/external" "opentofu/local"];
            opentofu.modules.kubeconfig = {
              resource.local_file.encrypted-kubeconfig = {
                content = "\${ yamlencode(jsondecode(data.external.encrypt-kubeconfig.result.kubeconfig)) }";
                filename = "\${ path.module }/kubeconfig.enc";
              };
              data.external.encrypt-kubeconfig.program = pkgs.execBash ''
                ${cluster.deploy.fetchKubeconfig} | \
                  ${getExe pkgs.sops} --encrypt --input-type binary --output-type binary /dev/stdin | \
                  ${getExe pkgs.yq} --raw-input '{"kubeconfig":.}'
              '';
            };
            opentofu.modules.kubectl-apply.resource.null_resource.kubernetes = {
              triggers.drv = cluster.configuration.drvPath;
              provisioner.local-exec.command = ''
                set -euo pipefail
                ssh sirver sudo k3s kubectl apply --server-side --prune -f ${cluster.configuration}
              '';
            };
          }
          (mkIf cluster.deploy.k3d {
            deploy.fetchKubeconfig = "echo '\${ k3d_cluster.main.credentials[0].raw }'";
            opentofu.plugins = ["pvotal-tech/k3d"];
            opentofu.modules.k3d.resource.k3d_cluster.main = {
              inherit name;
              servers = 1;
            };
          })
        ];
      }));
      default = {};
      description = "Kubernetes clusters";
    };
  };
}
