{inputs, ...}: {
  imports = [inputs.pre-commit.flakeModule];
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkAliasOptionModule mkEnableOption mkMerge mkIf mkOption mkDefault;
    cfg = config.canivete.pre-commit;
    toml = pkgs.formats.toml {};
  in {
    imports = [(mkAliasOptionModule ["canivete" "pre-commit"] ["pre-commit"])];
    options.pre-commit.languages = {
      python.enable = mkEnableOption "python language hooks";
      rust.enable = mkEnableOption "rust language hooks";
      shell.enable = mkEnableOption "shell script hooks";
      javascript.enable = mkEnableOption "js/ts script hooks";
      golang.enable = mkEnableOption "golang language hooks";
    };
    config = mkMerge [
      (mkIf config.canivete.just.enable {canivete.just.recipes."check *ARGS" = "pre-commit run --all-files --hook-stage manual {{ ARGS }}";})
      (mkIf config.canivete.devShells.enable {canivete.devShells.shells.shared.inputsFrom = [cfg.devShell];})
      {
        canivete.pre-commit.settings = {
          default_stages = ["pre-push" "manual"];
          excludes = [".canivete"];
          hooks = mkMerge [
            {
              # pre-commit builtin hooks
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
              no-commit-to-branch.enable = true;
              no-commit-to-branch.settings.branch = ["trunk"];
              trim-trailing-whitespace.enable = true;

              # third-party
              commitizen.enable = true;
              gitleaks.enable = true;
              gitleaks.entry = "${pkgs.gitleaks}/bin/gitleaks protect --redact";
              lychee.enable = true;
              markdownlint.enable = true;
              markdownlint.settings.configuration.MD013.line_length = -1;
              mdsh.enable = true;
              tagref.enable = true;
              typos.enable = true;

              # nix
              alejandra.enable = true;
              deadnix.enable = true;
              statix = {config, ...}: {
                options.toml = mkOption {
                  inherit (toml) type;
                  default = {};
                  description = "Contents of statix.toml";
                };
                config.enable = true;
                config.toml.disabled = mkDefault ["unquoted_uri" "repeated_keys"];
                config.raw.args = ["--config" (toml.generate "statix.toml" config.toml)];
              };
            }
            (mkIf cfg.languages.python.enable {
              # pre-commit builtin hooks
              check-builtin-literals.enable = true;
              check-docstring-first.enable = true;
              check-python.enable = true;
              name-tests-test.enable = true;
              python-debug-statements.enable = true;

              flake8.enable = true;
              mypy.enable = true;
              ruff.enable = true;
              taplo.enable = true;
            })
            (mkIf cfg.languages.rust.enable {
              clippy.enable = true;
              rustfmt.enable = true;
              taplo.enable = true;
            })
            (mkIf cfg.languages.shell.enable {
              shellcheck.enable = true;
              shfmt.enable = true;
              shfmt.raw.args = ["--indent" (toString 4)];
            })
            (mkIf cfg.languages.javascript.enable {
              biome.enable = true;
            })
            (mkIf cfg.languages.golang.enable {
              golangci-lint.enable = true;
            })
          ];
        };
      }
    ];
  };
}
