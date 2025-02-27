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

    # Nix flake framework
    flake-parts.url = github:hercules-ci/flake-parts;
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    # Git hook framework
    pre-commit.url = github:cachix/git-hooks.nix;
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit.inputs.nixpkgs-stable.follows = "nixpkgs-stable";

    # Terraform manifest generation
    terranix.url = github:terranix/terranix;
    terranix.inputs.nixpkgs.follows = "nixpkgs";

    # OpenTofu dependency registry
    # TODO should this be imported differently?
    opentofu-registry.url = github:opentofu/registry;
    opentofu-registry.flake = false;

    # Declarative software packaging
    # dream2nix.url = github:nix-community/dream2nix;
    # TODO follow changes upstream for better PDM support
    # NOTE might also consider moving away from PDM...
    dream2nix.url = github:schradert/dream2nix;
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";

    # Container composition framework
    # Arion has no argument to prefer buildLayeredImage when streamLayeredImage doesn't work across systems
    # arion.url = github:hercules-ci/arion;
    arion.url = github:schradert/arion/build-layer-image;
    arion.inputs.nixpkgs.follows = "nixpkgs";
    arion.inputs.flake-parts.follows = "flake-parts";

    # Kubernetes manifest generation
    # TODO follow updates and revert on merge
    # NOTE https://github.com/hall/kubenix/issues/52
    # kubenix.url = github:hall/kubenix;
    kubenix.url = github:schradert/kubenix/52-patch;
    kubenix.inputs.nixpkgs.follows = "nixpkgs";

    # RFC for flake output schemas
    # TODO check in to see if this is supported yet
    flake-schemas.url = github:DeterminateSystems/flake-schemas;

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
    nixos-anywhere.url = github:nix-community/nixos-anywhere;
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.inputs.flake-parts.follows = "flake-parts";

    # Declarative disk partitioning and formatting
    disko.url = github:nix-community/disko;
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Local service definitions (like docker without containers)
    process-compose.url = github:Platonic-Systems/process-compose-flake;
    services.url = github:juspay/services-flake;

    # Diagram generation for infrastructure dependencies
    nix-topology.url = github:oddlama/nix-topology;
    nix-topology.inputs.nixpkgs.follows = "nixpkgs";
    nix-topology.inputs.pre-commit-hooks.follows = "pre-commit";

    # Climod
    climod.url = github:nixosbrasil/climod;
    climod.flake = false;
  };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({
      canivete,
      lib,
      ...
    }: {
      imports = [./modules];
      flake.lib = canivete;
      flake.flakeModules = let
        inherit (lib) pipe flip nameValuePair match head listToAttrs;
      in
        pipe ./modules [
          canivete.filesets.nix.files
          (builtins.map (file:
            flip nameValuePair file (pipe file [
              builtins.baseNameOf
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
