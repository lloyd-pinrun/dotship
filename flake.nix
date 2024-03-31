{
  description = "Useful flake-parts modules";
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    nixpkgs-stable.url = github:nixos/nixpkgs/nixos-23.11;
    systems.url = github:nix-systems/default;

    flake-parts.url = github:hercules-ci/flake-parts;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    pre-commit.url = github:cachix/pre-commit-hooks.nix;
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit.inputs.nixpkgs-stable.follows = "nixpkgs-stable";
  };
  outputs = inputs:
    with inputs;
      flake-parts.lib.mkFlake {inherit inputs;} {
        imports = [./modules];
        flake.flakeModules = with self.lib;
          pipe ./modules [
            filesets.nix.files
            (map (file:
              flip nameValuePair file (pipe file [
                baseNameOf
                (match "^(.+)\.nix$")
                head
              ])))
            listToAttrs
          ];
        perSystem = {self', ...}: {
          devShells.default = self'.devShells.pre-commit;
        };
      };
}
