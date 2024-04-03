{
  description = "Useful flake-parts modules";
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    nixpkgs-stable.url = github:nixos/nixpkgs/nixos-23.11;
    systems.url = github:nix-systems/default;

    flake-parts.url = github:hercules-ci/flake-parts;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    pre-commit = {
      url = github:cachix/git-hooks.nix;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    };

    terranix.url = github:terranix/terranix;
    terranix.inputs.nixpkgs.follows = "nixpkgs";
    opentofu-registry.url = github:opentofu/registry/main;
    opentofu-registry.flake = false;
  };
  outputs = inputs:
    with inputs;
      flake-parts.lib.mkFlake {inherit inputs;} ({
        config,
        lib,
        ...
      }: {
        imports = [./modules];
        flake.flakeModules = with lib;
          pipe ./modules [
            config.canivete.filesets.nix.files
            (map (file:
              flip nameValuePair file (pipe file [
                baseNameOf
                (match "^(.+)\.nix$")
                head
              ])))
            listToAttrs
          ];
        perSystem.canivete.pre-commit.shell.enable = true;
      });
}
