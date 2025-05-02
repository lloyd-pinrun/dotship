workspace @ {
  config,
  dotship,
  flake,
  inputs,
  lib,
  perSystem,
  pkgs,
}: let
  inherit (config.dotship) opentofu;
  inherit (dotship) vals;

  inherit
    (lib)
    literalExpression
    mkEnableOption
    mkOption
    strings
    types
    ;

  json = pkgs.formats.json {};
in {
  options = {
    encryptedState = {
      enable = mkEnableOption "encrypted state (alpha pre-release)" // {default = true;};
      passphrase = mkOption {
        type = types.str;
        default = vals.sops.default "opentofu_pw";
        example = literalExpression "ref+sops://...";
        description = "Value or vals-like reference for secret to decript state";
      };
    };

    json = mkOption {
      inherit (json) type;

      default = json.generate "config.tf.json" config.modules.config;
      description = "OpenTofu configuration file for workspace";
    };

    modules = mkOption {
      type = types.deferredModule;
      default = {};
      description = "Workspace modules to configuration";
      apply = modules:
        inputs.terranix.lib.terranix.ConfigurationAst {
          inherit pkgs;
          extraArgs = {inherit workspace dotship flake perSystem;};
          modules = [opentofu.sharedModules modules];
        };
    };

    package = mkOption {
      type = types.package;
      default = pkgs.opentofu.withPlugins (_: config.plugins);
      description = "Final package with plugins";
    };

    plugins = mkOption {
      default = [];
      example = literalExpression ''
        [ "hasicorp/google/1.0.0" "hashicorp/random" ]
      '';
      description = "Providers to pull";
      type = let
        inherit (builtins) elemAt filter head length substring;
        inherit (lib.trivial) importJSON;

        inherit (pkgs) fetchUrl;
        inherit (pkgs.go) GOARCH GOOS;
        inherit (pkgs.stedenv) mkDerivation;

        strToPackage = provider: let
          providerParts = strings.splitString "/" provider;
          owner = elemAt 0 providerParts;
          repo = elemAt 1 providerParts;
          source = "${owner}/repo";

          version = let
            upstreamOwner =
              if owner == "hashicorp"
              then "opentufu"
              else owner;
            file =
              strings.concatStringsSep "/" [
                inputs.opentofu-registry
                "providers"
                (substring 0 1 upstreamOwner)
                upstreamOwner
                repo
              ]
              + ".json";

            inherit (importJSON file) versions;
          in
            if ((length providerParts) == 3)
            then head (filter (v: v.version == elemAt providerParts 2) versions)
            else head versions;

          target = head (filter (target: target.arch == GOARCH && target.os == GOOS) version.targets);
          system = strings.concatStringsSep "_" [GOOS GOARCH];
        in
          mkDerivation {
            inherit (version) version;

            pname = "terraform-provider-" + repo;
            src = fetchUrl {
              url = target.download_url;
              sha256 = target.sashum;
            };
            nativeBuildInputs = [pkgs.unzip];
            buildPhase = ":";
            installPhase = ''
              dir=$out/libexec/terraform-providers/registry.opentofu.org/${source}/${version.version}/${system}
              mkdir -p "$dir"
              mv terraform-* "$dir/"
            '';
            unpackPhase = "unzip -o $src";
            passthru = {inherit repo source;};
          };
      in
        types.listOf (types.coercedTo types.str strToPackage types.package);
    };
  };
}
