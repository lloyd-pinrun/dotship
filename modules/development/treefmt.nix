# TODO: expand config to support additional languages: rust, elixir, erlang & fish
{
  inputs,
  lib,
  ...
}: let
  devenvExists = inputs ? devenv;
  treefmtExists = inputs ? treefmt;
in {
  imports = [(inputs.treefmt.flakeModule or {})];

  config = lib.mkIf treefmtExists {
    perSystem = {
      config,
      lib,
      pkgs,
      ...
    }: let
      inherit (config.dotship) languages;
      inherit (config.treefmt.build) wrapper;
    in {
      imports = [(lib.mkAliasOptionModule ["dotship" "treefmt"] ["treefmt"])];

      formatter = wrapper;

      # NOTE:
      #  Including `treefmt` in `devenv.git-hooks`.
      #  Conditionally setting `formatters` based on `config.dotship.languages`.
      dotship.devenv.modules = lib.optionals devenvExists [
        {
          packages = [wrapper];

          git-hooks.hooks.treefmt = {
            enable = true;
            package = wrapper;
            settings.formatters = with pkgs;
              [keep-sorted]
              ++ lib.optionals languages.nix.enable [alejandra deadnix nixf-diagnose statix]
              ++ lib.optionals languages.shell.enable [shfmt shellcheck]
              ++ lib.optionals languages.python.enable [ruff ruff-format]
              ++ lib.optionals languages.lua.enable [stylua];
          };
        }
      ];

      treefmt = lib.mkMerge [
        (lib.mkIf languages.nix.enable {
          flakeCheck = true;
          flakeFormatter = true;
          projectRootFile = "flake.nix";
        })
        {
          programs = lib.mkMerge [
            {keep-sorted.enable = true;}
            (lib.mkIf languages.nix.enable {
              # -- nix --
              # keep-sorted start block=yes newline_separated=no
              alejandra.enable = true;
              deadnix.enable = true;
              nixf-diagnose = {
                enable = true;
                priority = -1;
              };
              statix = {
                enable = true;
                priority = -1;
              };
              # keep-sorted end
            })
            (lib.mkIf languages.shell.enable {
              # -- shell --
              # keep-sorted start block=yes newline_separated=no
              shellcheck.enable = true;
              shfmt = {
                enable = true;
                indent_size = 2;
              };
              # keep-sorted end
            })
            (lib.mkIf languages.python.enable {
              # -- python --
              # keep-sorted start block=yes newline_separated=no
              ruff-check = {
                enable = true;
                priority = 1;
              };
              ruff-format = {
                enable = true;
                priority = 2;
              };
              # keep-sorted end
            })
            (lib.mkIf languages.lua.enable {
              # -- lua --
              stylua.enable = true;
            })
          ];

          settings = lib.mkMerge [
            {
              global.excludes = [
                # keep-sorted start
                "*flake.lock"
                ".dotship"
                ".editorconfig"
                ".envrc"
                ".gitignore"
                # keep-sorted end
              ];
            }
            (lib.mkIf languages.nix.enable {
              formatter.nixf-diagnose.options = [
                # keep-sorted start
                "--auto-fix"
                # keep-sorted end
              ];
            })
            (lib.mkIf languages.shell.enable {formatter.shellcheck.options = ["-s" "bash"];})
          ];
        }
      ];
    };
  };
}
