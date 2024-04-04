# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
flake @ {
  flake-parts-lib,
  inputs,
  ...
}: {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({
    config,
    lib,
    pkgs,
    ...
  }:
    with lib; let
      cfg = config.canivete.opentofu;
    in {
      config = {
        devShells.canivete-opentofu = pkgs.mkShell {
          packages = with pkgs; [cfg.finalPackage terranix];
        };
        packages = mapAttrs (_: getAttr "configuration") cfg.workspaces;
        apps = mapAttrs (_: flip pipe [(getAttr "script") flake.config.flake.lib.mkApp]) cfg.workspaces;

        # required_providers here prevents opentofu from defaulting to fetching builtin hashicorp/<plugin-name>
        canivete.opentofu.sharedModules.plugins.terraform.required_providers = pipe cfg.plugins [
          (map (pkg: nameValuePair pkg.repo {inherit (pkg) source version;}))
          listToAttrs
        ];
      };
      options.canivete.opentofu = with types; {
        sharedModules = mkOption {
          type = attrsOf deferredModule;
          default = {};
          description = mdDoc "Terranix modules that every workspace should include";
        };
        workspaces = mkOption {
          default = {};
          description = mdDoc "Full OpenTofu configurations";
          type = attrsOf (submodule (workspace @ {name, ...}: {
            options = {
              module = mkOption {
                type = deferredModule;
                description = mdDoc "Terranix module to generate unique workspace configuration";
              };
              configuration = mkOption {
                type = package;
                description = mdDoc "OpenTofu configuration file for workspace";
                default = inputs.terranix.lib.terranixConfiguration {
                  inherit pkgs;
                  modules = concat (attrValues cfg.sharedModules) [workspace.config.module];
                };
              };
              script = mkOption {
                type = package;
                description = mdDoc "Script to run OpenTofu on the workspace configuration";
                default = pkgs.writeShellApplication {
                  name = "tofu-${name}";
                  runtimeInputs = with pkgs; [bash coreutils git vals cfg.finalPackage];
                  text = "${./utils.sh} ${./tofu.sh} --workspace ${name} --config ${workspace.config.configuration} -- \"$@\"";
                };
              };
            };
          }));
        };
        finalPackage = mkOption {
          type = package;
          default = pkgs.opentofu.withPlugins (_: cfg.plugins);
          description = mdDoc "Final package with plugins";
        };
        plugins = mkOption {
          default = [];
          description = mdDoc "Providers to pull";
          example = ["opentofu/google"];
          type = listOf (coercedTo str (
              source: let
                inherit (pkgs.go) GOARCH GOOS;

                # Parse registry reference from path
                sourceParts = strings.splitString "/" source;
                owner = elemAt sourceParts 0;
                repo = elemAt sourceParts 1;
                path = "registry.opentofu.org/${source}";

                # Target latest system version
                file = inputs.opentofu-registry + "/providers/${substring 0 1 owner}/${source}.json";
                latest = head (importJSON file).versions;
                target = head (filter (e: e.arch == GOARCH && e.os == GOOS) latest.targets);
              in
                pkgs.stdenv.mkDerivation rec {
                  inherit (latest) version;
                  pname = "terraform-provider-${repo}";
                  src = pkgs.fetchurl {
                    url = target.download_url;
                    sha256 = target.shasum;
                  };
                  unpackPhase = "unzip -o $src";
                  nativeBuildInputs = [pkgs.unzip];
                  buildPhase = ":";
                  # The upstream terraform wrapper assumes the provider filename here
                  installPhase = ''
                    dir=$out/libexec/terraform-providers/${path}/${version}/${GOOS}_${GOARCH}
                    mkdir -p "$dir"
                    mv terraform-* "$dir/"
                  '';
                  passthru = {inherit repo source;};
                }
            )
            package);
        };
      };
    });
}
