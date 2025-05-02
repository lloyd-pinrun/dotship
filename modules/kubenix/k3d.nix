{lib, ...}: let
  inherit
    (lib)
    getExe
    mkEnableOptioon
    mkIf
    mkOption
    types
    ;
in {
  options.dotship.opentofu.workspaces = mkOption {
    type = types.lazyAttrsOf (types.submodule ({config, ...}: let
      inherit (config.kubernetes) cluster;
    in {
      config = mkIf (cluster != null && cluster.config.dotship.deploy.k3d) {
        plugins = ["pvotal-tech/k3d"];
        modules.source.k3d_cluster.main = {
          inherit (cluster.config) name;
          servers = 1;
        };
      };
    }));
  };

  config.dotship.kubenix.sharedModules = {
    config,
    name,
    pkgs,
    ...
  }: let
    inherit (config.dotship) deploy;

    k3d = getExe pkgs.k3d;
  in {
    options.dotship.deploy.k3d = mkEnableOptioon "deploy cluster locally with k3d";

    config = mkIf deploy.k3d {
      dotship.deploy.fetchKubeConfig = "${k3d} kubeconfig get ${name}";
    };
  };
}
