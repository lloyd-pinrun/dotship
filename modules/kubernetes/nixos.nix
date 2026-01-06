{
  dot,
  config,
  flake,
  lib,
  target,
  pkgs,
  ...
}: let
  inherit (config.dotship) kubernetes;
  inherit (config.sops) secrets;

  inherit (flake.config.dotship) vars nixidy;

  k8s = pkgs.getName nixidy.k8s;
  service = config.services.${k8s};

  isRoot = target.name == vars.root;
  isServer = service.role == "server";
in {
  options.dotship.kubernetes = {
    enable = dot.options.enable "kubernetes" {};
    settings = dot.options.yaml pkgs "settings for config.yaml" {};
  };

  config = lib.mkIf kubernetes.enable (lib.mkMerge [
    {
      dotship.kubernetes.settings = {
        selinux = true;
        token-file = secrets."passwords/k8s-token".path;
      };

      environment.etc."rancher/${k8s}/config.yaml".source = dot.yaml.generate "${k8s}.yaml" kubernetes.settings;
      environment.systemPackages = [pkgs.${k8s}];

      services.${k8s} = {
        enable = true;
        role = lib.mkDefault "agent";
      };

      sops.secrets."passwords/k8s-token" = {};
      virtualisation.containerd.enable = true;
    }
    (lib.mkIf isServer {
      dotship.kubernetes.settings = {
        disable-cloud-controller = true;
        disable-kube-proxy = true;
        disable-scheduler = true;
        etcd-expose-metrics = true;
        tls-san = vars.domain;
      };
    })
    (lib.mkIf isRoot {services.${k8s}.role = "server";})
    (lib.mkIf (! isRoot) {dotship.kubernetes.settings.server = "https://${vars.domain}:6443";})
    (lib.mkIf (k8s == "k3s") (lib.mkMerge [
      {services.${k8s}.gracefulNodeShutdown.enable = true;}
      (lib.mkIf isRoot {services.${k8s}.clusterInit = true;})
      (lib.mkIf isServer {
        dotship.kubernetes.settings = {
          disable = ["traefik" "servicelb" "local-storage" "metrics-server" "coredns"];
          disable-network-policy = true;
          disable-helm-controller = true;
          flannel-backend = "none";
        };
      })
    ]))
    (lib.mkIf (k8s == "rke2" && isServer) {
      dotship.kubernetes.settings = {
        disable = ["rke2-coredns" "rke2-ingress-nginx" "rke2-metrics-server"];
        cni = "none";
      };
    })
  ]);
}
