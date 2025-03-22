{
  perSystem = {
    config,
    lib,
    ...
  }: let
    inherit (config.canivete.kubenix) clusters;
    inherit (lib) attrNames filterAttrs getExe mapAttrsToList mkIf mkOption pipe types;
    inherit (types) attrsOf coercedTo enum nullOr raw submodule;
  in {
    options.canivete.opentofu = {
      workspaces = mkOption {
        type = attrsOf (submodule ({config, ...}: {
          options.kubernetes.cluster = mkOption {
            type = nullOr (coercedTo (enum (attrNames clusters)) (name: clusters.${name}) raw);
            description = "Kubernetes cluster to deploy in this OpenTofu workspace";
          };
          config.plugins = mkIf (config.kubernetes.cluster != null) ["opentofu/null"];
        }));
      };
    };
    config.canivete.opentofu.sharedModules = {
      flake,
      pkgs,
      workspace,
      ...
    }: let
      inherit (workspace.config.kubernetes) cluster;
    in {
      config = mkIf (cluster != null) {
        resource.null_resource.kubernetes = {
          depends_on = pipe flake.config.canivete.deploy.nodes [
            (filterAttrs (_: node: node.canivete.os == "nixos" && node.profiles.system.canivete.configuration.config.canivete.kubernetes.enable))
            (mapAttrsToList (name: _: "null_resource.nixos_${name}_system"))
            (mkIf (workspace.name == "deploy"))
          ];
          triggers.drv = cluster.config.kubernetes.resultYAML.drvPath;
          provisioner.local-exec.command = ''
            set -euo pipefail
            ${getExe cluster.config.canivete.script} ${pkgs.kubectl}/bin/kubectl apply --server-side --prune -f -
          '';
        };
      };
    };
  };
}
