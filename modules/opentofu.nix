# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
{
  config,
  inputs,
  lib,
  ...
}: {
  options.canivete.opentofu = with lib; {
    plugins = mkOption {
      type = with types;
        listOf (submodule {
          options.owner = mkOption {type = str;};
          options.repo = mkOption {type = str;};
        });
      default = {};
      description = mdDoc "";
      example = lists.toList {
        owner = "opentofu";
        plugin = "google";
      };
    };
    registry = mkOption {
      default = inputs.opentofu-registry;
    };
  };
  config.perSystem = {
    pkgs,
    inputs',
    system,
    ...
  }: {
    packages.opentofu = let
      mkTerraformProvider = {
        owner,
        repo,
        version,
        src,
        registry ? "registry.opentofu.org",
      }: let
        inherit (pkgs.go) GOARCH GOOS;
        provider-source-address = "${registry}/${owner}/${repo}";
      in
        pkgs.stdenv.mkDerivation {
          pname = "terraform-provider-${repo}";
          inherit version src;
          unpackPhase = "unzip -o $src";
          nativeBuildInputs = [pkgs.unzip];
          buildPhase = ":";
          # The upstream terraform wrapper assumes the provider filename here.
          installPhase = ''
            dir=$out/libexec/terraform-providers/${provider-source-address}/${version}/${GOOS}_${GOARCH}
            mkdir -p "$dir"
            mv terraform-* "$dir/"
          '';

          passthru = {
            inherit provider-source-address;
          };
        };

      # fetch the latest version for the respective os and arch from the opentofu registry input
      providerFor = owner: repo: let
        file = config.canivete.opentofu.registry + "/providers/${lib.substring 0 1 owner}/${owner}/${repo}.json";
        latest = lib.head (lib.trivial.importJSON file).versions;

        arches.x86_64 = "amd64";
        arches.aarch64 = "arm64";
        systemParts = lib.strings.splitString "-" system;
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
    in
      pkgs.opentofu.withPlugins (_: lib.lists.forEach config.canivete.opentofu.plugins (plugin: providerFor plugin.owner plugin.repo));
  };
}
