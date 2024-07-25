{
  inputs,
  nix,
  ...
}:
with nix; {
  perSystem = {
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
    config.canivete.devShell.apps.kubectl.script = "nix run \".#canivete.${system}.kubenix.clusters.$1.script\" -- \"\${@:2}\"";
    config.canivete.opentofu.workspaces = mapAttrs (_: getAttr "opentofu") config.canivete.kubenix.clusters;
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
          opentofu = mkOption {
            # Can't use deferredModule here because it breaks merging with OpenTofu workspaces
            type = lazyAttrsOf anything;
            default = {};
            description = "OpenTofu workspace to deploy";
          };
          modules = mkModulesOption {};
          configuration = mkOption {
            type = package;
            description = "Kubernetes configuration file for cluster";
            default =
              (kubenix-patched.evalModules.${system} {
                specialArgs = {inherit nix;};
                module = {
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
                        evaluation = kubenix.evalModules {
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
              })
              .config
              .kubernetes
              .resultYAML;
          };
          script = mkOption {
            type = package;
            description = "Kubectl wrapper script for managing cluster";
            default = pkgs.writeShellApplication {
              name = "kubectl-${name}";
              runtimeInputs = with pkgs; [bash coreutils git vals sops kubectl yq];
              runtimeEnv.CANIVETE_UTILS = ../utils.sh;
              text = "${./kubectl.sh} --cluster ${name} --config ${cluster.configuration} -- \"$@\"";
            };
          };
        };
        config = mkMerge [
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
