{
  flake-parts-lib,
  inputs,
  lib,
  ...
}: {
  imports = [inputs.pre-commit.flakeModule];
  options.perSystem = with lib;
    flake-parts-lib.mkPerSystemOption ({
      config,
      pkgs,
      ...
    }: {
      options.canivete.pre-commit = {
        python.enable = mkEnableOption "python language hooks";
        rust.enable = mkEnableOption "rust language hooks";
        shell.enable = mkEnableOption "shell script hooks";
      };
      config = {
        devShells.canivete-pre-commit = config.pre-commit.devShell;

        pre-commit.settings.default_stages = ["push" "manual"];
        pre-commit.settings.hooks = let
          cfg = config.canivete.pre-commit;
        in
          mkMerge [
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
              mdsh.enable = true;
              tagref.enable = true;
              typos.enable = true;

              # nix
              alejandra.enable = true;
              deadnix.enable = true;
              statix.enable = true;
              statix.raw.args = [
                "--config"
                (pkgs.writers.writeTOML "statix.toml" {disabled = ["unquoted_uri" "repeated_keys"];})
              ];
            }
            (mkIf cfg.python.enable {
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
            (mkIf cfg.rust.enable {
              clippy.enable = true;
              rustfmt.enable = true;
              taplo.enable = true;
            })
            (mkIf cfg.shell.enable {
              shellcheck.enable = true;
              shfmt.enable = true;
            })
          ];
      };
    });
}
