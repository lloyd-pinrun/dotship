# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
{
  config,
  inputs,
  lib,
  ...
}: {
  options.canivete.opentofu.plugins = with lib;
    mkOption {
      type = with types;
        listOf (coercedTo str (path: let
            parts = lib.strings.splitString "/" path;
          in {
            owner = builtins.elemAt parts 0;
            repo = builtins.elemAt parts 1;
          }) (submodule {
            options.owner = mkOption {type = str;};
            options.repo = mkOption {type = str;};
          }));
      default = [];
      description = mdDoc "Providers to pull";
      example = [
        "opentofu/google"
        {
          owner = "opentofu";
          repo = "null";
        }
      ];
    };
  config.perSystem = {
    pkgs,
    inputs',
    system,
    ...
  }: {
    packages.opentofu = let
      registry = pkgs.fetchFromGitHub {
        owner = "opentofu";
        repo = "registry";
        rev = "main";
        hash = "sha256-JKY2HUV6ui9PlRA0+/k1QNdi9+IOHvKKl7kNiJxiJX8=";
      };
      arches = {
        x86_64 = "amd64";
        aarch64 = "arm64";
      };
      systemParts = lib.strings.splitString "-" system;
      mkTerraformProvider = {
        owner,
        repo,
        version,
        src,
      }: let
        inherit (pkgs.go) GOARCH GOOS;
        source = "registry.opentofu.org/${owner}/${repo}";
      in
        pkgs.stdenv.mkDerivation {
          pname = "terraform-provider-${repo}";
          inherit version src;
          unpackPhase = "unzip -o $src";
          nativeBuildInputs = [pkgs.unzip];
          buildPhase = ":";
          # The upstream terraform wrapper assumes the provider filename here.
          installPhase = ''
            dir=$out/libexec/terraform-providers/${source}/${version}/${GOOS}_${GOARCH}
            mkdir -p "$dir"
            mv terraform-* "$dir/"
          '';
          passthru.source = source;
        };

      # fetch the latest version for the respective os and arch from the opentofu registry input
      providerFor = owner: repo: let
        file = registry + "/providers/${lib.substring 0 1 owner}/${owner}/${repo}.json";
        latest = lib.head (lib.trivial.importJSON file).versions;

        arch = arches.${builtins.elemAt systemParts 0};
        os = builtins.elemAt systemParts 1;

        target = lib.head (lib.filter (e: e.arch == arch && e.os == os) latest.targets);
      in
        mkTerraformProvider {
          inherit (latest) version;
          inherit owner repo;
          src = pkgs.fetchurl {
            url = target.download_url;
            sha256 = target.shasum;
          };
        };

      plugins = lib.lists.forEach config.canivete.opentofu.plugins (plugin: providerFor plugin.owner plugin.repo);
    in
      pkgs.opentofu.withPlugins (_: plugins);
  };
}
