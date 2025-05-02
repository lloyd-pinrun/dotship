{
  inputs = {
    # -- ESSENTIALS --

    dotship.url = "github:lloyd-pinrun/dotship";

    # -- DEPLOYMENT --

    deploy-rs.url = "github:serokell/deploy-rs";
    disko.url = "github:nix-community/disko";
    home-manager.url = "github:nix-community/home-manager";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nix-darwin.url = "github:LnL7/nix-darwin";

    # -- DEVTOOLS --

    sops-nix.url = "github:Mic92/sops-nix";
    pre-commit.url = "github:cachix/git-hooks.nix";

    # -- MISC --

    flake-schemas.url = "github:DeterminateSystems/flake-schemas";
    nix-flake-schemas.url = "github:DeterminateSystems/nix-src/flake-schemas";

    climod.url = "github:nixosbrasil/climod";
    climod.flake = false;
  };

  outputs = inputs:
    inputs.dotship.lib.mkFlake {inherit inputs;} [] {
      dotship.meta = {
        root = "root";
        domain = "example.com";
        users.me = "cam";
        users.users.cam.description = "Cam";
      };

      dotship.deploy = {
        hosts."root".profiles.system.dotship.configuration.dotship.kubernetes.enable = true;
        dotship.modules.home-manager.home.stateVersion = "25.05";
        dotship.modules.nixos = {
          system.stateVersion = "25.05";
          boot.loader.systemd-boot.enable = true;

          disko.devices.disk.base = {
            device = "/dev/sda";
            type = "disk";
            content.type = "gpt";
            content.partitions = {
              ESP = {
                priority = 1;
                type = "EF00";
                size = "500M";
                content.type = "filesystem";
                content.format = "vfat";
                content.mountpoint = "/boot";
              };
              root = {
                priority = 2;
                end = "-1G";
                content.type = "filesystem";
                content.format = "ext4";
                content.mountpoint = "/";
              };
              swap = {
                size = "100%";
                content.type = "swap";
                content.discardPolicy = "both";
                content.resumeDevice = true;
              };
            };
          };
        };
      };

      perSystem.dotship = {
        kubenix.clusters.deploy = {
          canivete.deploy.fetchKubeconfig = "ssh \"root\" sudo k3s kubectl config view --raw | sed 's/127\.0\.0\.1/\"example.com\"/'";
          kubernetes.helm.releases.nginx.values.controllers.nginx.containers.nginx.image = {
            repository = "nginx";
            tag = "1.27.4-bookworm";
          };
        };
        opentofu.workspaces.deploy.kubernetes.cluster = "deploy";
      };
    };
}
