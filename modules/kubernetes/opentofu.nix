{
  dot,
  flake,
  lib,
  perSystem,
  ...
}: let
  inherit (flake.config.dotship) deploy opentofu vars;

  targets =
    lib.filterAttrs
    (_: target: let
      inherit (target.profiles.system.configuration.config.dotship.kubernetes) enable;
    in
      target.dotship.os == "nixos" && enable)
    deploy.targets;
in {
  config = lib.mkIf ((! dot.attrsets.isEmpty targets) && opentofu.enable) {
    passwords.k8s-token.length = 21;
    plugins = ["hashicorp/null"];

    modules = {
      resource.null_resource.kubernetes-bootstrap = {
        depends_on = ["null_resource.nixos_${vars.root}_system_install"];
        provisioner.local-exec.command = lib.getExe perSystem.self'.legacyPackages.nixidyEnvs.${perSystem.system}.prod.config.build.scripts.bootstrap;
      };
      module = lib.pipe targets [
        (lib.filterAttrs (name: _: name != vars.root))
        (lib.mapAttrs' (name: _: lib.nameValuePair "nixos_${name}_system_install" {depends_on = ["null_resource.kubernetes-bootstrap"];}))
      ];
    };
  };
}
