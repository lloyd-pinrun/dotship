{config, ...}: let
  flakeConfig = config;
in {
  canivete.deploy.nixos.modules.kubernetes = {
    canivete,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkEnableOption mkOption mkIf mkMerge mkDefault;
    inherit (flakeConfig.canivete.meta) domain;
    cfg = config.canivete.kubernetes;
    cfg_k3s = config.services.k3s;
  in {
    options.canivete.kubernetes = {
      enable = mkEnableOption "kubernetes as a service";
      root = mkEnableOption "node as kubernetes main control plane";
      k3s = mkOption {
        inherit (pkgs.formats.yaml {}) type;
        description = "Settings for /etc/rancher/k3s/config.yaml";
        default = {};
      };
    };
    config = mkIf cfg.enable (mkMerge [
      {
        canivete.secrets."random_password.k3s-token" = "result";
        canivete.kubernetes.k3s = {
          selinux = true;
          token-file = "/private/canivete/secrets/random_password.k3s-token";
        };
        environment.etc."rancher/k3s/config.yaml".source = pkgs.writers.writeYAML "k3s.yaml" cfg.k3s;
        environment.systemPackages = [pkgs.k3s];
        services.k3s = {
          enable = true;
          role = mkDefault "agent";
          configPath = "/etc/rancher/k3s/config.yaml";
          gracefulNodeShutdown.enable = true;
        };
        virtualisation.containerd.enable = true;
      }
      (canivete.mkIfElse cfg.root {
          services.k3s.role = "server";
          services.k3s.clusterInit = true;
        } {
          canivete.kubernetes.k3s.server = "https://${domain}:6443";
        })
      (mkIf (cfg_k3s.role == "server") {
        canivete.kubernetes.k3s = {
          # Barebones
          disable = ["traefik" "servicelb" "local-storage" "metrics-server" "coredns"];
          flannel-backend = "none";
          disable-kube-proxy = true;
          disable-network-policy = true;
          disable-helm-controller = true;
          # Server only
          etcd-expose-metrics = true;
          tls-san = [domain];
        };
      })
    ]);
  };
  perSystem = {
    config,
    lib,
    ...
  }: let
    inherit (lib) any attrValues mkIf;
    hasKubernetesNode = any (cfg: cfg.profiles.system.raw.config.canivete.kubernetes.enable) (attrValues flakeConfig.canivete.deploy.nixos.nodes);
  in {
    canivete = mkIf (hasKubernetesNode && config.canivete.opentofu.enable) {opentofu.workspaces.deploy.modules.k3s-token.resource.random_password.length = 21;};
  };
}
