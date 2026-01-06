flake @ {
  dotlib,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.dotship) nixidy;
in {
  options.dotship.nixidy = dotlib.options.submodule "nixidy" (nixidy: {
    options = {
      enable = dotlib.options.enable "nixidy" {default = inputs ? nixidy;};

      shared = dotlib.options.module "shared modules" {};
      envs = dotlib.options.attrs.module "environment configs" {};

      args = dotlib.options.attrs.anything "nixidy args" {};
      charts = dotlib.options.attrs.anything "nixidy charts" {};

      libOverlay = dotlib.options.overlay "extra lib functions" {};
      k8s = dotlib.options.enum ["k3s" "rke2"] "kubernetes distribution" {default = "k3s";};
    };

    config = {
      args = {inherit dotlib flake nixidy;};
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
