{
  description = "dotship";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";

    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    treefmt.url = "github:numtide/treefmt-nix";
    treefmt.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    specialArgs.dot = import ./lib.nix inputs.nixpkgs.lib;
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs specialArgs;} ({
      dot,
      lib,
      ...
    }: {
      imports = [./modules];

      flake = {
        inherit dot;
        lib.mkFlake = args: module: let
          _args = lib.mergeAttrs (removeAttrs args ["everything"]) {
            inputs = inputs // args.inputs;
            specialArgs = specialArgs // (args.specialArgs or {});
          };
          imports = lib.concat [module ./modules] (dot.filesets.nix.everything (args.everything or []));
        in
          inputs.flake-parts.lib.mkFlake _args {inherit imports;};
      };

      perSystem.dotship.languages = {
        # keep-sorted start
        nix.enable = true;
        shell.enable = true;
        # keep-sorted end
      };
    });
}
