{config, ...}: let
  inherit (config.canivete.deploy.nixos) nodes;
in {
  imports = [./options.nix];
  perSystem = {
    canivete,
    config,
    lib,
    pkgs,
    system,
    ...
  }: let
    inherit (lib) pipe mapAttrsToList mkMerge filterAttrs getExe mkOption mkDefault types toList mkIf;
    inherit (types) attrsOf submodule raw;
  in {
    canivete.opentofu.workspaces = pipe config.canivete.kubenix.clusters [
      (mapAttrsToList (name: cfg: {
        ${cfg.opentofuWorkspace} = mkMerge [
          {
            plugins = ["opentofu/null"];
            modules.kubenix.resource.null_resource.kubernetes = {
              depends_on = pipe nodes [
                (filterAttrs (_: node: node.profiles.system.raw.config.dotfiles.kubernetes.enable))
                (mapAttrsToList (name: _: "null_resource.nixos_${name}_system"))
                (mkIf (cfg.opentofuWorkspace == "deploy"))
              ];
              triggers.drv = cfg.configuration.drvPath;
              provisioner.local-exec.command = ''
                set -euo pipefail
                ${getExe cfg.script} ${pkgs.kubectl}/bin/kubectl apply --server-side --prune -f -
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
    canivete.kubenix.sharedModules.defaults = {config, ...}: {
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
}
