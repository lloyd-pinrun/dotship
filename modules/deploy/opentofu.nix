flake @ {
  dot,
  config,
  lib,
  ...
}: let
  inherit (config.dotship.deploy) dotship nodes;
in {
  dotship.deploy = _: {
    options.nodes = dot.options.attrs.withSubmodule {
      options.profiles = dot.options.attrs.withSubmodule ({
        config,
        name,
        node,
        ...
      }: let
        inherit (dotship) flakes;
        inherit (config.dotship) type;

        resourceName = "${type}_${node.name}_${name}";
      in {
        dotship.configuration = {
          options.dotship.opentofu = dot.options.module "opentofu modules for profile" {};

          config.dotship.opentofu = {
            config,
            pkgs,
            ...
          }: {
            config = lib.mkMerge [
              {
                data.external.${resourceName}.program = pkgs.execBash ''
                  nix eval .#dotship.deploy.nodes.${node.name}.profiles.${name}.path.drvPath | ${lib.getExe pkgs.jq} '{drvPath:.}'
                '';

                resources.null_resource.${resourceName} = {
                  triggers.drvPath = "\${ data.external.${resourceName}.result.drvPath }";

                  # WARN: deploy-rs currently runs all flake checks, which can fail when correctly deploying
                  # TODO: track https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/opentofu.nix#L43
                  provisioner.local-exec.command = let
                    inherit (flakes.deploy.packages.${pkgs.system}) default;
                  in ''
                    ${lib.getExe default} --skip-checks .#\"${node.name}\".\"${name}\"
                  '';
                };
              }
              (lib.mkIf (type == "nixos") {
                data.external.${resourceName}.depends_on = ["module.${resourceName}_install"];

                module."${resourceName}_install" = lib.mkMerge [
                  {
                    source = "${flakes.anywhere}//terraform/install";
                    target_host = node.config.hostname;
                    flake = ".#${node.name}";
                  }
                  (lib.mkIf (dot.trivial.isNull flakes.disko) {phases = ["kexec" "install" "reboot"];})
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
      getNodeImports = node: builtins.map getProfileImport (builtins.attrValues node.profiles);
    in
      lib.pipe nodes [builtins.attrValues (builtins.concatMap getNodeImports)];
  };
}
