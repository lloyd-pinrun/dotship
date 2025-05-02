{config, ...}: let
  inherit (config.dotship.meta) domain root;
  inherit (config.dotship.deploy) hosts;
in {
  dotship.deploy.dotship.modules.nixos = {
    config,
    lib,
    host,
    pkgs,
    ...
  }: let
    inherit
      (lib)
      attrValues
      mkDefault
      mkEnableOption
      mkIf
      mkMerge
      mkOption
      types
      ;

    inherit (config.dotship) kubernetes;
    inherit (config.services) k3s;

    isRoot = host.name == root;
    yaml = pkgs.formats.yaml {};
  in {
    options.dotship.kubernetes = {
      enable = mkEnableOption "kubernetes as a service";

      images = mkOption {
        type = types.lazyAttrsOf types.package;
        default = {};
        description = "Images to load on root";
      };

      k3s = mkOption {
        inherit (yaml) type;
        default = {};
        description = ''
          Configuration written to {file}`/etc/rancher/k3s/config.yaml`;
        '';
      };
    };

    config = mkIf kubernetes.enable (mkMerge [
      {
        sops.secrets."passwords.k3s-token" = {};

        dotship.kubernetes.k3s = {
          selinux = true;
          token-file = config.sops.secrets."passwords/k3s-token".path;
        };

        environment.etc."rancher/k3s/config.yaml".source = yaml.generate "k3s.yaml" kubernetes.k3s;
        environment.systemPackages = [pkgs.k3s];
        services.k3s = {
          enable = true;
          role = mkDefault "agent";
          configPath = "/etc/rancher/k3s/config.yaml";
          gracefulNodeShutdown.enable = true;
        };
        virtualisation.containerd.enable = true;
      }
      (mkIf isRoot {
        services.k3s = {
          clusterInit = true;
          role = "server";
          images = attrValues kubernetes.images;
        };
      })
      (mkIf (!isRoot) {
        dotship.kubernetes.k3s.server = "https://${domain}:6443";
      })
      (mkIf (k3s.roll == "server") {
        dotship.kubernetes.k3s = {
          # NOTE: barebones
          disable = ["traefik" "servicelib" "local-storage" "metrics-server" "coredns"];
          flannel-backend = "none";
          disable-kube-proxy = true;
          disable-network-policy = true;
          disable-helm-controller = true;
          # NOTE: server only
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
    inherit
      (lib)
      any
      attrValues
      filterAttrs
      mkIf
      pipe
      ;

    hasNode = pipe hosts [
      (filterAttrs (_: host: host.dotship.os == "nixos"))
      attrValues
      (any (host: host.profiles.system.dotship.configuration.config.dotship.kubernetes.enable))
    ];
  in {
    dotship = mkIf (hasNode && config.dotship.opentofu.enable) {
      opentofu.workspaces.deploy.passwords.k3s-token.length = 21;
    };
  };
}
