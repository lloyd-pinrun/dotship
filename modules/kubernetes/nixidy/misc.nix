{
  dot,
  config,
  lib,
  perSystem,
  ...
}: let
  inherit (config) nixidy;
in {
  options.build.scripts.nixidy = dot.options.package "nixidy executable" {internal = true;};

  config.build.scripts.nixidy = perSystem.inputs'.nixidy.packages.default;
  config.nixidy = {
    target = {
      branch = lib.mkDefault "main";
      rootPath = lib.mkDefault "./generated/nixidy/${nixidy.env}";
    };

    defaults.helm.transformer = map (lib.kube.removeLabels [
      # NOTE: helm chart versions are not necessary
      # SOURCE: https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/kubernetes/nixidy/misc.nix#L13-L18
      "app.kubernetes.io/version"
      "helm.sh/chart"
    ]);
  };
}
