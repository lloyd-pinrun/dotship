{
  dotlib,
  config,
  lib,
  ...
}: let
  inherit (config.dotship.deploy) dotship targets;
in {
  dotship.deploy = _: {
    options.targets = dotlib.options.attrs.withSubmodule {
      options.profiles = dotlib.options.attrs.withSubmodule ({
        config,
        name,
        target,
        ...
      }: let
        inherit (dotship) flakes;
        inherit (config.dotship) type;

        resourceName = "${type}_${target.name}_${name}";
      in {
        dotship.configuration = {
          options.dotship.opentofu = dotlib.options.module "opentofu modules for profile" {};

          config.dotship.opentofu = {
            config,
            pkgs,
            ...
          }: {
            config = lib.mkMerge [
              {
                data.external.${resourceName}.program = pkgs.execBash ''
                  nix eval .#dotship.deploy.targets.${target.name}.profiles.${name}.path.drvPath | ${lib.getExe pkgs.jq} '{drvPath:.}'
                '';

                resources.null_resource.${resourceName} = {
                  triggers.drvPath = "\${ data.external.${resourceName}.result.drvPath }";

                  # WARN: deploy-rs currently runs all flake checks, which can fail when correctly deploying
                  # TODO: track https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/opentofu.nix#L43
                  provisioner.local-exec.command = let
                    inherit (flakes.deploy.packages.${pkgs.system}) default;
                  in ''
                    ${lib.getExe default} --skip-checks .#\"${target.name}\".\"${name}\"
                  '';
                };
              }
              (lib.mkIf (type == "nixos") {
                data.external.${resourceName}.depends_on = ["module.${resourceName}_install"];

                module."${resourceName}_install" = lib.mkMerge [
                  {
                    source = "${flakes.anywhere}//terraform/install";
                    target_host = target.config.hostname;
                    flake = ".#${target.name}";
                  }
                  (lib.mkIf (dotlib.trivial.isNull flakes.disko) {phases = ["kexec" "install" "reboot"];})
                  (lib.mkIf (config.resource.null_resource ? sops) {depends_on = ["null_resource.sops"];})
                ];
              })
            ];
          };
        };
      });
    };
  };

  perSystem.dotship.opentofu.workspaces.deploy = {
    plugins = ["hashicorp/null" "hashicorp/external"];

    modules.imports = let
      getProfileImport = lib.getAttrFromPath ["dotship" "configuration" "config" "dotship" "opentofu"];
      getTargetImports = target: map getProfileImport (builtins.attrValues target.profiles);
    in
      lib.pipe targets [builtins.attrValues (builtins.concatMap getTargetImports)];
  };
}
