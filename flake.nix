{
  description = "flake-parts modules";

  inputs = {
    # -- Essential --
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # -- Development --
    just.url = "github:lloyd-pinrun/just.nix";
    just.inputs = {
      flake-parts.follows = "flake-parts";
      nixpkgs.follows = "nixpkgs";
      pre-commit.follows = "pre-commit";
    };
    pre-commit.url = "github:cachix/git-hooks.nix";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({
      dotship,
      lib,
      ...
    }: {
      imports = [./modules];

      flake.lib = {inherit (dotship.lib) mkFlake;};

      flake.flakeModules = let
        inherit (builtins) baseNameOf map match head listToAttrs;
        inherit (lib) flip nameValuePair pipe;
      in
        pipe ./modules [
          dotship.filesets.nix.files
          (map (file:
            flip nameValuePair file (pipe file [
              baseNameOf
              (match "^(.+)\.nix$")
              head
            ])))
          listToAttrs
        ];

      flake.templates.default = {
        path = ./template;
        description = "basic dotship template";
      };

      perSystem.dotship.pre-commit.languages.shell.enable = true;
    });
}
