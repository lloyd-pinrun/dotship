{
  description = "Useful flake-parts modules";
  inputs = {
    # Common upstream software dependencies
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    nixpkgs-stable.url = github:nixos/nixpkgs/nixos-23.11;

    # Supported systems
    systems.url = github:nix-systems/default;
    systems-default.url = github:nix-systems/x86_64-linux;
    systems-darwin.url = github:nix-systems/aarch64-darwin;

    # Flake-parts compatibility for profiles
    nixos-flake.url = github:srid/nixos-flake;

    # Nix flake framework
    flake-parts.url = github:hercules-ci/flake-parts;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    # Git hook framework
    pre-commit = {
      url = github:cachix/git-hooks.nix;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    };

    # Terraform manifest generation
    terranix.url = github:terranix/terranix;
    terranix.inputs.nixpkgs.follows = "nixpkgs";

    # OpenTofu dependency registry
    # TODO should this be imported differently?
    opentofu-registry.url = github:opentofu/registry;
    opentofu-registry.flake = false;

    # Declarative software packaging
    dream2nix.url = github:nix-community/dream2nix;
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";

    # Container composition framework
    arion = {
      url = github:hercules-ci/arion;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.hercules-ci-effects.inputs.flake-parts.follows = "arion/flake-parts";
      inputs.hercules-ci-effects.inputs.nixpkgs.follows = "arion/nixpkgs";
    };

    # Kubernetes manifest generation
    kubenix.url = github:hall/kubenix;
    kubenix.inputs.nixpkgs.follows = "nixpkgs";

    # RFC for flake output schemas
    # TODO check in to see if this is supported yet
    flake-schemas.url = github:DeterminateSystems/flake-schemas;

    # Nix profile deployment framework
    deploy-rs.url = github:serokell/deploy-rs;
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    # User software configuration framework
    home-manager.url = github:nix-community/home-manager;
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Darwin system configuration framework
    nix-darwin.url = github:LnL7/nix-darwin;
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Android system configuration framework
    nix-on-droid.url = github:nix-community/nix-on-droid;
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";

    # Generate NixOS builds for different formats
    nixos-generators.url = github:nix-community/nixos-generators;
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    # Bootstrap a new NixOS machine
    nixos-anywhere = {
      url = github:nix-community/nixos-anywhere;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Common configuration modules for NixOS servers
    srvos.url = github:nix-community/srvos;
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    # Declarative disk partitioning and formatting
    disko.url = github:nix-community/disko;
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Robust derivation for referening a flake
    call-flake.url = github:divnix/call-flake;
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
        perSystem.canivete.pre-commit.languages.shell.enable = true;
      });
}
