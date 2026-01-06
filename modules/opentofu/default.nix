flake @ {
  dotlib,
  config,
  inputs,
  ...
}: let
  inherit (config.dotship.opentofu) enable;
in {
  options.dotship.opentofu.enable = dotlib.options.enable "OpenTofu workspaces" {default = inputs ? terranix;};

  config.perSystem = perSystem @ {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.dotship) opentofu;
  in {
    config = lib.mkIf enable {
      dotship.devenv.shells.default.scripts.tofu.exec = "nix run .#dotship.$(nix eval --raw --impure --expra \"builtins.currentSystem\").opentofu.script \"\${NIX_OPTIONS[@]}\" -- \"$@\"";
    };

    options.dotship.opentofu = {
      directory = dotlib.options.str "path relative to project root to store OpenTofu state" {default = ".dotship/opentofu";};

      script = dotlib.options.package "activation script" {
        default = pkgs.writeShellApplication {
          name = "opentofu";
          runtimeInputs = with pkgs; [git gum usage yq] ++ [pkgs.dotship pkgs.vals];
          text = builtins.readFile ./opentofu.sh;
        };
      };

      sharedModules = dotlib.options.module "shared OpenTofu modules" {};
      workspaces = dotlib.options.attrs.submodule "OpenTofu workspaces" (workspace @ {config, ...}: {
        options = {
          encrypted-state = {
            enable = dotlib.options.enable "encrypted state (alpha prerelease)" {};
            passphrase = dotlib.options.str "vals reference to decrypt state" {default = dotlib.vals.sops.default "opentofu_pw";};
          };

          package = dotlib.options.package "final package with plugins" {default = pkgs.opentofu.withPlugins (_: config.plugins);};

          json = dotlib.options.package "opentofu configuration file for workspace" {
            default = (pkgs.formats.json {}).generate "config.tf.json" config.modules.config;
          };

          modules = dotlib.options.module "workspace modules to configuration" {
            apply = modules:
              inputs.terranix.lib.terranixConfigurationAst {
                inherit pkgs;
                extraArgs = {inherit workspace dotlib flake perSystem;};
                modules = [opentofu.sharedModules modules];
              };
          };

          plugins = lib.mkOption {
            default = [];
            description = "Providers to pull";
            example = ["hashicorp/google/1.0.0" "hashicorp/random"];
            type = let
              inherit (pkgs) go;
              strToPackage = provider: let
                # NOTE: Parse source (e.g. "owner/repo[/versionTry]")
                providerParts = lib.splitString "/" provider;
                owner = lib.elemAt providerParts 0;
                repo = lib.elemAt providerParts 1;
                source = "${owner}/${repo}";

                # NOTE: Target system version (latest by default)
                version = let
                  upstreamOwner = dotlib.trivial.turnary (owner == "hashicorp") "opentofu" owner;
                  file = inputs.opentofu-registry + "/providers/${builtins.substring 0 1 upstreamOwner}/${upstreamOwner}/${repo}.json";
                  inherit (lib.importJSON file) versions;
                  hasSpecificVersion = (builtins.length providerParts) == 3;
                  specificVersion = builtins.head (builtins.filter (v: v.version == lib.elemAt providerParts 2) versions);
                  latestVersion = builtins.head versions;
                in
                  dotlib.trivial.turnary hasSpecificVersion specificVersion latestVersion;
                target = builtins.head (builtins.filter (t: t.arch == go.GOARCH && t.os == go.GOOS) version.targets);
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
                    dir=$out/libexec/terraform-providers/registry.opentofu.org/${source}/${version.version}/${go.GOOS}_${go.GOARCH}
                    mkdir -p "$dir"
                    mv terraform-* "$dir/"
                  '';
                  passthru = {inherit repo source;};
                };
            in
              with lib.types; listOf (coercedTo str strToPackage package);
          };
        };

        config.modules = {
          variable.GIT_DIR.type = "string";
          terraform = lib.mkMerge [
            {
              # required_providers here prevents opentofu from defaulting to fetching builtin hashicorp/<plugin-name>
              required_providers = lib.pipe config.plugins [
                (map (pkg: lib.nameValuePair pkg.repo {inherit (pkg) source version;}))
                builtins.listToAttrs
              ];
            }
            (lib.mkIf config.encryptedState.enable {
              encryption = {
                key_provider.pbkdf2.default.passphrase = lib.mkDefault config.encryptedState.passphrase;
                method.aes_gcm.default.keys = "\${ key_provider.pbkdf2.default }";
                state.method = lib.mkDefault "\${ method.aes_gcm.default }";
                state.fallback = lib.mkDefault {method = "\${ method.aes_gcm.default }";};
                plan.method = lib.mkDefault "\${ method.aes_gcm.default }";
                plan.fallback = lib.mkDefault {method = "\${ method.aes_gcm.default }";};
              };
            })
          ];
        };
      });
    };
  };
}
