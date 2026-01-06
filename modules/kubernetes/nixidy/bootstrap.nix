{
  dotlib,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config) applications nixidy;
  inherit (config.build) scripts;

  concatObjectInfo = object: builtins.concatStringsSep "/" [object.apiVersion object.kind object.metadata.name];
in {
  options.build.scripts.bootstrap = dotlib.options.package "bootstrap command for cluster" {internal = true;};

  config = {
    nixidy.applicationImports = [
      (_: {
        options.dotship.bootstrap = {
          enable = dotlib.options.enable "importing resources into cluster bootstrap" {};
          exclude = dotlib.options.list.str "resources to exclude from bootstrap" {};
        };
      })
    ];

    applications.__bootstrap.objects = lib.pipe nixidy.publicApps [
      (builtins.filter (name: name != nixidy.appOfApps.name))
      (map (name: applications.${name}))
      # WARN:
      #   this may need to be changed to `app.dotfiles.bootstrap.enable`
      #   see: https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/kubernetes/nixidy/bootstrap.nix#L23
      (builtins.filter (app: app.dotship.bootstrap.enable))
      (map (app: builtins.filter (object: ! (builtins.elem (concatObjectInfo object) app.dotship.bootstrap.exclude)) app.objects))
      lib.flatten
    ];

    build.scripts.bootstrap = pkgs.mkShellApplication {
      name = "nixidy-bootstrap-${nixidy.env}";
      runtimeInputs = with pkgs; [git kapp vals scripts.nixidy scripts.kubeconfig];

      # NOTE: vals needs to run in the project root to read sops
      text = ''
        cd "$(git rev-parse --show-toplevel)"
        nixidy bootstrap .#${nixidy.env} | \
          vals eval -s -decode-kubernetes-secrets -f - | \
          kubeconfig kapp deploy --yes --diff-changes --app bootstrap --file -
      '';
    };
  };
}
