# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
{flake-parts-lib, ...}: {
  options.perSystem = flake-parts-lib.mkPerSystemOption ({
    config,
    lib,
    pkgs,
    system,
    ...
  }: {
    options.canivete.opentofu = with lib;
    with types; {
      registry = mkOption {
        type = package;
        default = pkgs.fetchFromGitHub {
          owner = "opentofu";
          repo = "registry";
          rev = "main";
          hash = "sha256-JKY2HUV6ui9PlRA0+/k1QNdi9+IOHvKKl7kNiJxiJX8=";
        };
      };
      terranixModule = mkOption {
        type = deferredModule;
        default.terraform.required_providers = listToAttrs (forEach config.canivete.opentofu.plugins (pkg:
          nameValuePair pkg.repo {
            inherit (pkg) source version;
          }));
      };
      finalPackage = mkOption {
        type = package;
        default = pkgs.opentofu.withPlugins (_: config.canivete.opentofu.plugins);
        description = mdDoc "Final package with plugins";
      };
      plugins = mkOption {
        default = [];
        description = mdDoc "Providers to pull";
        example = ["opentofu/google"];
        type = listOf (coercedTo str (
            source: let
              inherit (pkgs.go) GOARCH GOOS;

              # Map nix system to registry labels
              arches = {
                x86_64 = "amd64";
                aarch64 = "arm64";
              };
              systemParts = strings.splitString "-" system;
              arch = arches.${elemAt systemParts 0};
              os = elemAt systemParts 1;

              # Parse registry reference from path
              sourceParts = strings.splitString "/" source;
              owner = elemAt sourceParts 0;
              repo = elemAt sourceParts 1;
              path = "registry.opentofu.org/${source}";

              # Target latest system version
              file = config.canivete.opentofu.registry + "/providers/${substring 0 1 owner}/${source}.json";
              latest = head (importJSON file).versions;
              target = head (filter (e: e.arch == arch && e.os == os) latest.targets);
            in
              pkgs.stdenv.mkDerivation rec {
                pname = "terraform-provider-${repo}";
                version = latest.version;
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
