# TODO: expand config to support additional languages: rust, elixir, erlang & fish
{
  dotlib,
  inputs,
  lib,
  ...
}: let
  devenvExists = inputs ? devenv;
in {
  imports = [(inputs.devenv.flakeModule or {})];

  config = lib.mkIf devenvExists {
    perSystem = {
      config,
      lib,
      ...
    }: let
      inherit (config.dotship) languages;
    in {
      imports = [(lib.mkAliasOptionModule ["dotship" "devenv"] ["devenv"])];

      devenv.modules = [
        ({pkgs, ...}: {
          inherit languages;
          packages = lib.optionals languages.nix.enable (with pkgs; [nix-inspect nix-prefetch-docker]);

          git-hooks.default_stages = lib.mkDefault ["pre-push" "manual"];
          git-hooks.excludes = [".dotship"];
          git-hooks.hooks = lib.mkMerge [
            {
              # -- git-hooks builtins --
              # keep-sorted start block=yes newline_separated=no
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
              no-commit-to-branch = {
                enable = false;
                settings.branch = ["main"];
              };
              trim-trailing-whitespace.enable = true;
              # keep-sorted end

              # -- third-party --
              # keep-sorted start block=yes newline_separated=no
              commitizen.enable = true;
              gitleaks = {
                enable = true;
                entry = "${lib.getExe pkgs.gitleaks} protect --redact";
              };
              lychee = {config, ...}: {
                options.toml = dotlib.options.toml pkgs "contents of lychee.toml" {};

                config = {
                  enable = true;
                  settings.configPath = toString (dotlib.formats.toml.generate pkgs "lychee.toml" config.toml);
                };
              };
              markdownlint = {
                enable = true;
                settings.configuration = {
                  MD033.allowed_elements = ["h1" "code"];
                  MD013.line_length = -1;
                };
              };
              mdsh.enable = true;
              typos.enable = true;
              # keep-sorted end
            }
            (lib.mkIf languages.nix.enable {
              # -- nix --
              # keep-sorted start
              flake-checker.enable = true;
              # keep-sorted end
            })
            (lib.mkIf languages.python.enable {
              # -- git-hooks builtins --
              # keep-sorted start
              check-builtin-literals.enable = true;
              check-docstring-first.enable = true;
              check-python.enable = true;
              name-tests-test.enable = true;
              python-debug-statements.enable = true;
              # keep-sorted end
            })
          ];
        })
      ];
    };
  };
}
