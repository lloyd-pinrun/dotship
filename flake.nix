{
  description = "Useful flake-parts modules";
  inputs = {
    # Essential
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # Development
    pre-commit.url = "github:cachix/git-hooks.nix";
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({
      canivete,
      lib,
      ...
    }: {
      imports = [./modules];
      flake.lib = canivete;
      # TODO what about directories? how should these be handled? use every nix file?
      flake.flakeModules = let
        inherit (builtins) baseNameOf map match head listToAttrs;
        inherit (lib) flip nameValuePair pipe;
      in
        pipe ./modules [
          canivete.filesets.nix.files
          (map (file:
            flip nameValuePair file (pipe file [
              baseNameOf
              (match "^(.+)\.nix$")
              head
            ])))
          listToAttrs
        ];
      # TODO add WAYYY more templates
      flake.templates.default = {
        path = ./template;
        description = "Basic canivete template";
      };
      perSystem.canivete.pre-commit.languages.shell.enable = true;
    });
}
