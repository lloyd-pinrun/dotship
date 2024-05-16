{
  inputs,
  nix,
  ...
}:
with nix; {
  options.perSystem = mkPerSystemOption ({
    config,
    pkgs,
    system,
    ...
  }: {
    config.apps.kubectl = mkApp (pkgs.writeShellApplication {
      name = "kubectl";
      text = "${./utils.sh} nixCmd run \".#canivete.${system}.kubenix.clusters.$1.script\" -- \"\${@:2}\"";
    });
    options.canivete.kubenix.clusters = mkOption {
      type = attrsOf (submodule ({
        config,
        name,
        ...
      }: let
        cluster = config;
      in {
        options = {
          k3d = mkEnableOption "Deploy cluster locally with k3d";
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
              (inputs.kubenix.evalModules.${system} {
                specialArgs = {inherit nix;};
                module = {kubenix, ...}: {
                  imports = with kubenix.modules; [k8s helm] ++ attrValues cluster.modules;
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
              runtimeInputs = with pkgs; [bash coreutils git vals kubectl];
              runtimeEnv.CANIVETE_UTILS = ./utils.sh;
              text = "${./kubectl.sh} --cluster ${name} --config ${cluster.configuration} -- \"$@\"";
            };
          };
        };
        config = mkIf cluster.k3d {
          opentofu.plugins = ["pvotal-tech/k3d" "opentofu/external" "opentofu/local"];
          opentofu.modules.k3d = {
            resource.k3d_cluster.main = {
              inherit name;
              servers = 1;
            };
            data.external.encrypt-kubeconfig = {
              program = pkgs.execBash "echo '\${ k3d_cluster.main.credentials[0].raw }' | ${getExe pkgs.sops} --encrypt --input-type yaml --output-type yaml /dev/stdin | ${getExe pkgs.yq} '{\"kubeconfig\":.}'";
            };
            resource.local_file.encrypted-kubeconfig = {
              content = "\${ data.external.encrypt-kubeconfig.result.kubeconfig }";
              filename = "\${ path.module }/kubeconfig.enc";
            };
          };
        };
      }));
      default = {};
      description = "Kubernetes clusters";
    };
    config.canivete.opentofu.workspaces = mapAttrs' (name: cluster: nameValuePair "kubenix-${name}" cluster.opentofu) config.canivete.kubenix.clusters;
  });
}
