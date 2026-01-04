{
  dot,
  flake,
  config,
  lib,
  name,
  node,
  ...
}: let
  inherit (config.dotship) activator args builder configuration type;

  inherit (node.config.dotship) os system;

  inherit (flake.config.dotship.deploy) dotship;
  inherit (flake.deploy.lib.${system}) activate;

  module.types = {
    nixos = "nixos";
    darwin = "darwin";
    windows = "nixos";
    linux = "home-manager";
  };

  module.activators = let
    inherit (activate) darwin nixos home-manager;
    # MAYBE: introduce android deployment https://github.com/schradert/canivete/trunk/modules/deploy/profile.nix#L38
    custom = base: activate.custom base.dotship.activation.package (lib.getExe base.dotship.activation.package);
  in {
    inherit custom darwin nixos home-manager;
  };

  module.builders = let
    custom = _modules: let
      modules = [_modules];
      specialArgs = args;
    in
      lib.evalModules {inherit modules specialArgs;};

    darwin = _modules: let
      inherit (dotship.flakes.darwin.lib) darwinSystem;

      modules = [_modules];
      specialArgs = args;
    in
      darwinSystem {inherit modules specialArgs;};

    nixos = _modules: let
      inherit (dotship.flakes.nixos.lib) nixosSystem;
      modules = [_modules];
      specialArgs = args;
    in
      nixosSystem {inherit modules specialArgs;};

    home-manager = _modules: let
      inherit (dotship.flakes.home-manager.lib) homeManagerConfiguration;

      modules = [_modules];
      extraSpecialArgs = args;
    in
      flake.withSystem system (_flake:
        homeManagerConfiguration {
          inherit (_flake) pkgs;
          inherit modules extraSpecialArgs;
        });
  in {
    inherit custom darwin nixos home-manager;
  };
in {
  imports = [./generic.nix];

  options = {
    path = dot.options.pathInStore "path to activation script for given derivation" {default = activator configuration;};
    profile-path = dot.options.opt.path "profile installation path" {};

    dotship = {
      args = dot.options.attrs.anything "arguments based to configuration" {};
      activator = dot.options.function.pathInStore "build instructions for derivation activation script" {default = module.activators.${type};};
      builder = dot.options.function.raw "convert modules to configurations" {default = module.builders.${type};};
      configuration = dot.options.module "central module and configuration derivation for profile" {apply = builder;};
      type = dot.options.enum ["home-manager" "nixos" "darwin" "custom"] "config module type" {default = module.types.${os};};
    };
  };

  config = let
    defaultConfiguration = {
      options.dotship.activation-package = dot.options.package "final package for custom profile" {};
    };
    configuration = dotship.modules.${type} or defaultConfiguration;

    users = {
      home-manager = name;
      nixos = "root";
      darwin = "root";
    };
    user = users.${type} or null;

    # WARN: avoids fixpoint infinite recursion
    profile = {
      inherit name;
      config = {inherit (config) dotship;};
    };
  in {
    remote.user = lib.mkDefault user;

    dotship = {
      inherit configuration;
      args = {inherit dot flake profile node;};
    };
  };
}
