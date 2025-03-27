flake @ {inputs, ...}: {
  imports = [./nixos.nix ./opentofu.nix];
  perSystem = perSystem @ {
    canivete,
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    inherit (lib) getExe mapAttrs mkDefault mkEnableOption mkIf mkOption types;
    inherit (types) attrsOf deferredModule listOf package str submodule;
  in {
    imports = [./k3d.nix];
    config = mkIf config.canivete.kubenix.enable {
      canivete.pre-commit.settings.hooks.lychee.toml.exclude = ["svc.cluster.local"];
      canivete.kubenix.sharedModules = {
        config,
        helm,
        kubenix,
        name,
        ...
      }: {
        imports = [kubenix.modules.k8s kubenix.modules.helm];
        config._module.args = {inherit canivete flake perSystem system;};
        options.canivete = {
          deploy.fetchKubeconfig = mkOption {
            type = str;
            description = "Script to fetch the kubeconfig of an externally managed Kubernetes cluster. Stdout is the contents of the file";
          };
          apps = mkOption {
            type = listOf str;
            default = [];
            description = "Order of resource deployment with kapp";
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
                ${config.canivete.deploy.fetchKubeconfig} >"$KUBECONFIG"

                nix build .#canivete.${system}.kubenix.clusters.${name}.config.kubernetes.resultYAML --no-link --print-out-paths | \
                  xargs cat | \
                  ${getExe pkgs.vals} eval -s -f - | \
                  ${getExe pkgs.yq} "." --yaml-output | \
                  ${getExe pkgs.bash} -c "$@"
              '';
            };
          };
        };
        options.kubernetes.helm.releases = mkOption {
          type = attrsOf (submodule {
            chart = mkDefault (helm.fetch {
              repo = "https://bjw-s.github.io/helm-charts";
              chart = "app-template";
              version = "3.7.3";
              sha256 = "sha256-ZkgsF4Edl+s044BR4oQIXDS3S6pT/B8V3TEjDQzx6eE=";
            });
          });
        };
      };
    };
    options.canivete.kubenix = {
      enable = mkEnableOption "kubenix package builds" // {default = inputs ? kubenix;};
      script = mkOption {
        type = package;
        default = pkgs.writeShellApplication {
          name = "kubenix";
          text = "nix run \".#canivete.${system}.kubenix.clusters.$1.script\" -- \"\${@:2}\"";
        };
      };
      sharedModules = mkOption {
        type = deferredModule;
        default = {};
        description = "";
      };
      clusters = mkOption {
        type = attrsOf deferredModule;
        default = {};
        description = "Clusters";
        apply = mapAttrs (
          name: modules:
            import ./ifd.nix (
              inputs.kubenix.evalModules.${system} {
                modules = [modules config.canivete.kubenix.sharedModules {_module.args = {inherit name;};}];
              }
            )
        );
      };
    };
  };
}
