{
  inputs = {
    # Essentials
    # NOTE replace with:
    # canivete.url = "github:schradert/canivete";
    canivete.url = "path:..";
    # flake-parts.url = "github:hercules-ci/flake-parts";
    # canivete.inputs.flake-parts.follows = "flake-parts";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # canivete.inputs.nixpkgs.follows = "nixpkgs";
    # systems.url = "github:nix-systems/default";
    # canivete.inputs.systems.follows = "systems";

    # Deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    home-manager.url = "github:nix-community/home-manager";
    nix-on-droid.url = "github:nix-community/nix-on-droid";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    disko.url = "github:nix-community/disko";
    nix-darwin.url = "github:LnL7/nix-darwin";

    # OpenTofu
    terranix.url = "github:terranix/terranix";
    opentofu-registry.url = "github:opentofu/registry";
    opentofu-registry.flake = false;

    # Containers + Kubernetes
    kubenix.url = "github:hall/kubenix";
    nix2container.url = "github:nlewo/nix2container";
    # NOTE Arion has no argument to prefer buildLayeredImage when streamLayeredImage doesn't work across systems
    # arion.url = "github:hercules-ci/arion";
    arion.url = "github:schradert/arion/build-layer-image";

    # Development tools
    sops-nix.url = "github:Mic92/sops-nix";
    pre-commit.url = "github:cachix/git-hooks.nix";
    # canivete.inputs.pre-commit.follows = "pre-commit";
    process-compose.url = "github:Platonic-Systems/process-compose-flake";
    services.url = "github:juspay/services-flake";

    # Misc.
    dream2nix.url = "github:nix-community/dream2nix";
    flake-schemas.url = "github:DeterminateSystems/flake-schemas";
    climod.url = "github:hercules-ci/flake-parts";
    climod.flake = false;
  };
  # Arguments are:
  # 1. flake-parts module args
  # 2. directories where every .nix file recursively is a flake-parts module
  # 3. root flake-parts module
  outputs = inputs: inputs.canivete.lib.mkFlake {inherit inputs;} [] {};
}
