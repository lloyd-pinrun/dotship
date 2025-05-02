flake @ {inputs, ...}: {
  imports = [./nixos.nix ./opentofu.nix];

  perSystem = perSystem @ {
    dotship,
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    inherit
      (lib)
      getExe
      mapAttrs
      mapAttrsToList
      mkDefault
      mkEnableOption
      mkIf
      mkMerge
      mkOption
      pipe
      types
      ;
  in {
    imports = [./k3d.nix];

    options.dotship.kubenix = {
      enable = mkEnableOption "kubenix package builds" // {default = inputs ? kubenix;};

      script = mkOption {
        type = types.package;
        default = pkgs.writeShellApplication {
          name = "kubenix";
          text = "nix run \".#dotship.${system}.kubenix.clusters.$1.script\" -- \"\${@:2}\"";
        };
      };

      sharedModules = mkOption {
        type = types.deferredModule;
        default = {};
      };

      clusters = mkOption {
        type = types.attrsOf types.deferredModule;
        default = {};
        description = "clusters";
        apply = mapAttrs (
          name: modules:
            import ./ifd.nix (
              inputs.kubenix.evalModules.${system} {
                modules = [modules config.dotship.kubenix.sharedModules {_module.args = {inherit name;};}];
              }
            )
        );
      };
    };

    config = mkIf config.dotship.kubenix.enable {
      dotship.pre-commit.hooks.lychee.toml.exclude = ["svc.cluster.local"];
      dotship.kubenix.sharedModules = {
        config,
        helm,
        kubenix,
        name,
        ...
      }: let
        inherit (config.kubernetes.helm) releases;
      in {
        imports = [kubenix.modules.k8s kubenix.modules.helm];

        config = {
          _module.args = {inherit dotship flake perSystem system;};
          kubernetes.api.resources = pipe releases [
            (mapAttrsToList (
              _: release:
                mapAttrs (
                  _:
                    mapAttrs (
                      _: resource:
                        mkMerge ([resource] ++ release.overrides)
                    )
                )
                release.extraResources
            ))
            mkMerge
          ];

          kubernetes.customTypes.kappconfig = {
            attrName = "kappconfig";
            group = "kapp.k14s.io";
            version = "v1alpha1";
            kind = "Config";
          };
        };

        options.dotship = {
          deploy.fetchKubeConfig = mkOption {
            type = types.str;
            description = ''
              Script to fetch the kubeconfig of an externally managed k8s cluster -- `stdout` is the contents of the file.
            '';
          };

          script = mkOption {
            type = types.package;
            description = "wrapper script";
            default = let
              bash = getExe pkgs.bash;
              git = getExe pkgs.git;
              vals = getExe pkgs.vals;
            in
              pkgs.writeShellApplication {
                inherit name;

                # NOTE: vals needs to run in project root to access sops config
                text = ''
                  cd "$(${git} rev-parse --show-toplevel)"

                  # connect to cluster
                  KUBECONFIG="$(mktemp)"
                  export KUBECONFIG
                  trap 'rm -f "$KUBECONFIG"' EXIT
                  ${config.dotship.deploy.fetchKubeConfig} >"$KUBECONFIG"

                  nix build .#dotship.${system}.kubenix.clusters.${name}.config.kubernetes.resultYAML --no-link --print-out-paths | \
                    xargs cat | \
                    ${vals} eval -s -decode-kubernetes-secrets -f - | \
                    ${bash} -c "$*"
                '';
              };
          };
        };

        options.kubernetes.helm.releases = let
          yaml = pkgs.formats.yaml {};
        in
          mkOption {
            type = types.attrsOf (types.submodule ({config, ...}: {
              options.extraResources = mkOption {
                type = types.attrsOf (types.attrsOf yaml.type);
                default = {};
                description = ''
                  Extra resources to attach to Helm release. Top-level is plural name,
                  e.g. kubernetes.resources, for optimal merging.
                '';
              };

              config.overrideNamespace = false;
              config.overrides = [
                {metadata.annotations."chart.dotship.app/${config.name}" = "";}
                {metadata.namespace = mkDefault config.namespace;}
              ];
              config.chart = mkDefault (helm.fetch {
                repo = "https://bjw-s.github.io/helm-charts";
                chart = "app-template";
                version = "3.7.3";
                sha256 = "sha256-ZkgsF4Edl+s044BR4oQIXDS3S6pT/B8V3TEjDQzx6eE=";
              });
            }));
          };
      };
    };
  };
}
