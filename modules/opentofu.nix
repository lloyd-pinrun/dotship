# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
flake @ {...}: {
  perSystem = {
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
      finalPackage = mkOption {
        type = package;
        default = pkgs.opentofu.withPlugins (_: attrValues config.canivete.opentofu.plugins);
        description = mdDoc "Final package with plugins";
      };
      plugins = mkOption {
        default = [];
        description = mdDoc "Providers to pull";
        example = ["opentofu/google"];
        type = coercedTo (listOf str) (
          paths: let
            inherit (pkgs.go) GOARCH GOOS;

            # Map nix system to registry labels
            arches = {
              x86_64 = "amd64";
              aarch64 = "arm64";
            };
            systemParts = strings.splitString "-" system;
            arch = arches.${elemAt systemParts 0};
            os = elemAt systemParts 1;

            mkProvider = path: let
              # Parse registry reference from path
              pathParts = strings.splitString "/" path;
              owner = elemAt pathParts 0;
              repo = elemAt pathParts 1;
              source = "registry.opentofu.org/${owner}/${repo}";

              # Target latest system version
              file = config.canivete.opentofu.registry + "/providers/${substring 0 1 owner}/${owner}/${repo}.json";
              latest = head (importJSON file).versions;
              target = head (filter (e: e.arch == arch && e.os == os) latest.targets);
            in
              nameValuePair path (pkgs.stdenv.mkDerivation rec {
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
                  dir=$out/libexec/terraform-providers/${source}/${version}/${GOOS}_${GOARCH}
                  mkdir -p "$dir"
                  mv terraform-* "$dir/"
                '';
                passthru.source = source;
              });
          in
            listToAttrs (map mkProvider paths)
        ) (attrsOf package);
      };
    };
  };
}
