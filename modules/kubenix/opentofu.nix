{
  perSystem = {
    config,
    lib,
    ...
  }: let
    inherit (config.dotship.kubenix) clusters;

    inherit
      (lib)
      attrNames
      filterAttrs
      getExe
      mapAttrsToList
      mkIf
      mkOption
      pipe
      types
      ;
  in {
    options.dotship.opentofu = {
      workspaces = mkOption {
        type = types.lazyAttrsOf (types.submodule ({config, ...}: {
          options.kubernetes.cluster = mkOption {
            type = types.nullOr (types.coercedTo (types.enum (attrNames clusters)) (name: clusters.${name}) types.raw);
            description = "kubernetes cluster to deploy in this OpenTofu workspace";
          };

          config.plugins = mkIf (config.kubernetes.cluster != null) ["hashicorp/null"];
        }));
      };
    };

    config.dotship.opentofu.sharedModules = {
      flake,
      pkgs,
      workspace,
      ...
    }: let
      inherit (flake.config.dotship.deploy) hosts;
      inherit (workspace.config.kubernetes) cluster;

      script = getExe cluster.config.dotship.script;
      kapp = getExe pkgs.kapp;
    in {
      config = mkIf (cluster != null) {
        resources.null_resource.kubernetes = {
          depends_on = pipe hosts [
            (filterAttrs (_: host: host.dotship.os == "nixos" && host.profiles.system.dotship.configuration.config.dotship.kubernetes.enable))
            (mapAttrsToList (name: _: "null_resource.nixos_${name}_system"))
            (mkIf (workspace.name == "deploy"))
          ];
          triggers.drv = cluster.config.kubernetes.resultYAML.drvPath;
          provisioners.local-exec.command = "${script} ${kapp} deploy --yes --app everything --file -";
        };
      };
    };
  };
}
