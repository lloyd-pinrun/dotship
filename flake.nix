{
  description = "Useful flake-parts modules";
  inputs = {
    # nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    # Pinning this while xz exploit is being resolved in unstable stream
    nixpkgs.url = github:nixos/nixpkgs/f72123158996b8d4449de481897d855bc47c7bf6;
    nixpkgs-stable.url = github:nixos/nixpkgs/nixos-23.11;
    systems.url = github:nix-systems/default;

    flake-parts.url = github:hercules-ci/flake-parts;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    pre-commit.url = github:cachix/pre-commit-hooks.nix;
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit.inputs.nixpkgs-stable.follows = "nixpkgs-stable";

    terranix.url = github:terranix/terranix;
    terranix.inputs.nixpkgs.follows = "nixpkgs";
    opentofu-registry.url = github:opentofu/registry/main;
    opentofu-registry.flake = false;
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
      };
}
