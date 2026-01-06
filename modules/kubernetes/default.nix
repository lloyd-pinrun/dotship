flake @ {
  dot,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.dotship) nixidy;
in {
  options.dotship.nixidy = dot.options.submodule "nixidy" (nixidy: {
    options = {
      enable = dot.options.enable "nixidy" {default = inputs ? nixidy;};

      shared = dot.options.module "shared modules" {};
      envs = dot.options.attrs.module "environment configs" {};

      args = dot.options.attrs.anything "nixidy args" {};
      charts = dot.options.attrs.anything "nixidy charts" {};

      libOverlay = dot.options.overlay "extra lib functions" {};
      k8s = dot.options.enum ["k3s" "rke2"] "kubernetes distribution" {default = "k3s";};
    };

    config = {
      args = {inherit dot flake nixidy;};
      shared = ./nixidy;
      envs.prod = {};
    };
  });

  config = lib.mkMerge [
    {
      dotship.deploy.dotship.modules.nixos = ./nixos.nix;
      perSystem.dotship.opentofu.workspaces.deploy = ./opentofu.nix;
    }
    (lib.mkIf nixidy.enable {
      perSystem = perSystem @ {
        inputs',
        pkgs,
        self',
        system,
        ...
      }: {
        packages.nixidy = inputs'.nixidy.packages.default;

        dotship.devenv.modules = [
          {
            git-hooks.hooks.lychee.toml.exclude = ["svc.cluster.local"];
            packages = [self'.packages.nixidy];
          }
        ];

        legacyPackages.nixidyEnvs.${system} = inputs.nixidy.lib.mkEnvs {
          inherit pkgs;
          inherit (nixidy) envs libOverlay;

          modules = [nixidy.shared];
          extraSpecialArgs = nixidy.args // {inherit perSystem;};
          charts =
            lib.mkIf (inputs ? nixhelm)
            (inputs.nixhelm.chartsDerivations.${system} or {})
            // nixidy.charts;
        };
      };
    })
  ];
}
