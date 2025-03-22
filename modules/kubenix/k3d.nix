{lib, ...}: let
  inherit (lib) getExe mkIf mkEnableOption mkOption types;
in {
  options.canivete.opentofu.workspaces = mkOption {
    type = types.attrsOf (types.submodule ({config, ...}: let
      inherit (config.kubernetes) cluster;
    in {
      config = mkIf cluster.config.canivete.deploy.k3d {
        plugins = ["pvotal-tech/k3d"];
        modules.resource.k3d_cluster.main = {
          # TODO does this work?
          inherit (cluster.config) name;
          servers = 1;
        };
      };
    }));
  };
  config.canivete.kubenix.sharedModules = {
    config,
    name,
    pkgs,
    ...
  }: {
    options.canivete.deploy.k3d = mkEnableOption "Deploy cluster locally with k3d";
    config = mkIf config.canivete.deploy.k3d {
      canivete.deploy.fetchKubeconfig = "${getExe pkgs.k3d} kubeconfig get ${name}";
    };
  };
}
