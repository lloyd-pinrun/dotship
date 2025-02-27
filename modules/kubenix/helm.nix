{
  perSystem = {
    canivete,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkDefault mkIf mkMerge mkOption optionalAttrs types;
    inherit (types) attrsOf submodule anything deferredModule;
    yaml = pkgs.formats.yaml {};
  in {
    config = mkMerge [
      (mkIf config.canivete.pre-commit.enable {pre-commit.settings.hooks.lychee.toml.exclude = ["svc.cluster.local"];})
    ];
    options.canivete.kubenix.helm = mkOption {
      default = {};
      type = attrsOf (submodule ({
        config,
        name,
        ...
      }: {
        freeformType = anything;
        options = {
          chart = mkOption {
            type = attrsOf anything;
            default = {};
          };
          values = mkOption {
            inherit (yaml) type;
            default = {};
          };
          resources = mkOption {
            type = attrsOf (attrsOf (submodule {
              freeformType = yaml.type;
              config.metadata = mkMerge [
                {lagbels."canivete/chart" = mkDefault name;}
                (optionalAttrs (config ? namespace) {inherit (config) namespace;})
              ];
            }));
            default = {};
          };
          kubenix = mkOption {
            type = deferredModule;
            default = {};
          };
        };
        config = {
          chart = mkDefault {
            repo = "https://bjw-s.github.io/helm-charts";
            chart = "app-template";
            version = "3.3.2";
            sha256 = "9Lx3jPGiLaE+joGy2GWxLzjWDu8wCa+4DrS9atf2zug=";
          };
          resources = optionalAttrs (config ? namespace) {namespaces.${config.namespace} = {};};
          kubenix = {helm, ...}: {
            kubernetes = {
              inherit (config) resources;
              helm.releases.${name} = mkMerge [
                (removeAttrs config ["chart" "resources" "kubenix"])
                {chart = helm.fetch config.chart;}
              ];
            };
          };
        };
      }));
    };
  };
}
