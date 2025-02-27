# Adapted from https://gist.github.com/bcd2b4e0d3a30abbdec19573083b34b7.git
# OpenTofu has issues finding Terraform plugins added with .withPlugins, so this module will patch that
# NOTE https://github.com/nix-community/nixpkgs-terraform-providers-bin/issues/52
{inputs, ...}: {
  imports = [./sops.nix];
  perSystem = {
    canivete,
    config,
    lib,
    options,
    pkgs,
    ...
  }: let
    inherit (canivete) vals ifElse mkEnabledOption;
    inherit (lib) mkOption mkEnableOption nameValuePair mkIf concat listToAttrs pipe types mkMerge mkDefault attrValues importJSON head length filter elemAt substring strings readFile;
    inherit (types) attrsOf submodule raw package str listOf coercedTo deferredModule;
    tofu = config.canivete.opentofu;
    tofuOpts = options.canivete.opentofu;
  in {
    config = mkIf tofu.enable {
      canivete.just.recipes."tofu *ARGS" = "nix run .#canivete.$(nix eval --raw --impure --expr \"builtins.currentSystem\").opentofu.script \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}";
    };
    options.canivete.opentofu = {
      enable = mkEnableOption "OpenTofu workspaces" // {default = inputs ? terranix;};
      script = mkOption {
        type = package;
        default = pkgs.writeShellApplication {
          name = "opentofu";
          runtimeInputs = with pkgs; [git gum yq] ++ [pkgs.vals config.canivete.scripts.utils];
          text = readFile ./opentofu.sh;
        };
      };
      workspaces = mkOption {
        default = {};
        description = "Full OpenTofu configurations";
        type = attrsOf (submodule ({config, ...}: let
          workspace = config;
        in {
          options = {
            encryptedState.enable = mkEnabledOption "encrypted state (alpha prerelease)";
            encryptedState.passphrase =
              tofuOpts.sharedEncryptedStatePassphrase
              // {
                default = tofu.sharedEncryptedStatePassphrase;
              };
            plugins = tofuOpts.sharedPlugins;
            modules = tofuOpts.sharedModules;
            package = mkOption {
              type = package;
              default = pkgs.opentofu;
              description = "Final package with plugins";
            };
            finalPackage = mkOption {
              type = package;
              default = workspace.package.withPlugins (_: workspace.plugins);
              description = "Final package with plugins";
            };
            composition = mkOption {
              type = raw;
              description = "Evaluated terranix composition";
              default = inputs.terranix.lib.terranixConfigurationAst {
                inherit pkgs;
                extraArgs = {inherit canivete;};
                modules = attrValues workspace.modules;
              };
            };
            configuration = mkOption {
              type = package;
              description = "OpenTofu configuration file for workspace";
              default = (pkgs.formats.json {}).generate "config.tf.json" workspace.composition.config;
            };
          };
          config.plugins = tofu.sharedPlugins;
          config.modules = mkMerge [
            tofu.sharedModules
            # required_providers here prevents opentofu from defaulting to fetching builtin hashicorp/<plugin-name>
            {
              plugins.terraform.required_providers = pipe workspace.plugins [
                # TODO why do I need to be explicit here as well?!
                (concat tofu.sharedPlugins)
                (map (pkg: nameValuePair pkg.repo {inherit (pkg) source version;}))
                listToAttrs
              ];
            }
            (mkIf workspace.encryptedState.enable {
              state.terraform.encryption = {
                key_provider.pbkdf2.default.passphrase = mkDefault workspace.encryptedState.passphrase;
                method.aes_gcm.default.keys = "\${ key_provider.pbkdf2.default }";
                state.method = mkDefault "\${ method.aes_gcm.default }";
                state.fallback = mkDefault {method = "\${ method.aes_gcm.default }";};
                plan.method = mkDefault "\${ method.aes_gcm.default }";
                plan.fallback = mkDefault {method = "\${ method.aes_gcm.default }";};
              };
            })
          ];
        }));
      };
      sharedEncryptedStatePassphrase = mkOption {
        type = str;
        default = vals.sops "default.yaml#/opentofu_pw";
        description = "Value or vals-like reference (i.e. ref+sops://... or with nix.vals.sops) to secret to decrypt state";
      };
      sharedModules = mkOption {
        type = attrsOf deferredModule;
        default = {};
        description = "Terranix modules";
      };
      sharedPlugins = mkOption {
        default = [];
        description = "Providers to pull";
        example = ["opentofu/google/1.0.0" "opentofu/random"];
        type = listOf (coercedTo str (
            provider: let
              inherit (pkgs.go) GOARCH GOOS;

              # Parse source (e.g. "owner/repo[/versionTry]")
              providerParts = strings.splitString "/" provider;
              owner = elemAt providerParts 0;
              repo = elemAt providerParts 1;
              source = "${owner}/${repo}";

              # Target system version (latest by default)
              version = let
                file = inputs.opentofu-registry + "/providers/${substring 0 1 owner}/${source}.json";
                inherit (importJSON file) versions;
                hasSpecificVersion = (length providerParts) == 3;
                specificVersion = head (filter (v: v.version == elemAt providerParts 2) versions);
                latestVersion = head versions;
              in
                ifElse hasSpecificVersion specificVersion latestVersion;
              target = head (filter (t: t.arch == GOARCH && t.os == GOOS) version.targets);
            in
              pkgs.stdenv.mkDerivation {
                inherit (version) version;
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
                  dir=$out/libexec/terraform-providers/registry.opentofu.org/${source}/${version.version}/${GOOS}_${GOARCH}
                  mkdir -p "$dir"
                  mv terraform-* "$dir/"
                '';
                passthru = {inherit repo source;};
              }
          )
          package);
      };
    };
  };
}
