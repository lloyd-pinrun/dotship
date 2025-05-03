{inputs, ...}: {
  imports = [inputs.pre-commit.flakeModule];

  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.dotship) pre-commit;

    inherit
      (lib)
      getExe
      mkAliasOptionModule
      mkEnableOption
      mkMerge
      mkIf
      mkOption
      mkDefault
      ;

    toml = pkgs.formats.toml {};
  in {
    imports = [(mkAliasOptionModule ["dotship" "pre-commit"] ["pre-commit"])];

    options.pre-commit.languages = {
      rust.enable = mkEnableOption "rust language hooks";
      shell.enable = mkEnableOption "shell script hooks";
    };

    config = mkMerge [
      (mkIf config.just.enable {
        just.recipes."check *ARGS" = "pre-commit run --all-files --hook-stage manual {{ ARGS }}";
      })
      (mkIf config.dotship.devShells.enable {
        dotship.devShells.shells.shared.inputsFrom = [pre-commit.devShell];
      })
      {
        dotship.pre-commit.settings = {
          default_stages = ["pre-push" "manual"];
          excludes = [".dotship"];
          hooks = mkMerge [
            {
              #built-in hooks
              check-added-large-files.enable = true;
              check-case-conflicts.enable = true;
              check-executables-have-shebangs.enable = true;
              check-merge-conflicts.enable = true;
              check-symlinks.enable = true;
              check-vcs-permalinks.enable = true;
              end-of-file-fixer.enable = true;
              fix-byte-order-marker.enable = true;
              forbid-new-submodules.enable = true;
              mixed-line-endings.enable = true;
              no-commit-to-branch.enable = false;
              no-commit-to-branch.settings.branch = ["main"];
              trim-trailing-whitespace.enable = true;

              # external hooks
              commitizen.enable = true;
              gitleaks.enable = true;
              gitleaks.entry = "${getExe pkgs.gitleaks} protect --redact";

              lychee = {config, ...}: {
                options.toml = mkOption {
                  inherit (toml) type;
                  default = {};
                  description = "Contents of lychee.toml";
                };

                config = {
                  enable = true;
                  settings.configPath = builtins.toString (toml.generate "lychee.toml" config.toml);
                };
              };

              markdownlint.enable = true;
              markdownlint.settings.configuration.MD013.line_length = -1;

              mdsh.enable = true;
              tagref.enable = true;
              typos.enable = true;

              # nix hooks
              alejandra.enable = true;
              deadnix = {
                enable = true;
                settings.edit = true;
              };

              statix = {config, ...}: {
                options.toml = mkOption {
                  inherit (toml) type;

                  default = {};
                  description = "Contents of statix.toml";
                };

                config = {
                  enable = true;
                  toml.disabled = mkDefault ["unquoted_uri" "repeated_keys"];
                  raw.args = ["--config" (toml.generate "statix.toml" config.toml)];
                };
              };
            }
            (mkIf pre-commit.languages.rust.enable {
              clippy.enable = true;
              rustfmt.enable = true;
              taplo.enable = true;
            })
            (mkIf pre-commit.languages.shell.enable {
              shellcheck.enable = true;

              shfmt = {
                enable = true;
                raw.args = ["--indent" (toString 2)];
              };
            })
          ];
        };
      }
    ];
  };
}
