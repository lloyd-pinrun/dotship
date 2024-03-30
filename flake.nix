{
  description = "Useful flake-parts modules without a dedicated home";
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    nixpkgs-stable.url = github:nixos/nixpkgs/nixos-23.11;

    flake-parts.url = github:hercules-ci/flake-parts;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    pre-commit.url = github:cachix/pre-commit-hooks.nix;
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit.inputs.nixpkgs-stable.follows = "nixpkgs-stable";

    systems.url = github:nix-systems/default;
  };
  outputs = inputs:
    with inputs;
      flake-parts.lib.mkFlake {inherit inputs;} {
        imports = [pre-commit.flakeModule];
        systems = import systems;
        flake.flakeModules.opentofu = ./modules/opentofu.nix;
        perSystem = {config, ...}: {
          devShells.default = config.pre-commit.devShell;
          pre-commit.settings.default_stages = ["push" "manual"];
          pre-commit.settings.hooks.alejandra.enable = true;
        };
      };
}
