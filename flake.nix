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

    dream2nix.url = github:nix-community/dream2nix;
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";

    arion = {
      url = github:hercules-ci/arion;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.hercules-ci-effects.inputs.flake-parts.follows = "arion/flake-parts";
      inputs.hercules-ci-effects.inputs.nixpkgs.follows = "arion/nixpkgs";
    };

    kubenix.url = github:hall/kubenix;
    kubenix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs:
    with inputs;
      flake-parts.lib.mkFlake {inherit inputs;} (flake @ {config, ...}: let
        nix = import ./lib.nix flake;
      in {
        imports = [./modules];
        _module.args.nix = nix;
        flake = {
          lib.mkFlake = with nix;
            args @ {
              specialArgs ? {},
              everything ? [],
              ...
            }: module:
              flake-parts.lib.mkFlake {
                inputs = inputs // args.inputs;
                specialArgs = {inherit nix;} // specialArgs;
              } {
                imports = concat [module self.flakeModule] (nix.filesets.nix.everything everything);
                perSystem._module.args.nix = nix;
              };
          flakeModule = config.flake.flakeModules.default;
          flakeModules = with nix;
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
        perSystem.canivete.pre-commit.shell.enable = true;
      });
}
