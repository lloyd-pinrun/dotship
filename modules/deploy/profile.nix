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
  inherit (flake.config.dotship.deploy.dotship) flakes modules;
  inherit (flake.deploy.lib.${system}) activate;
in {
  imports = [./generic.nix];

  options = {
    path = dot.options.pathInStore "path to activation script for given derivation" {default = activator configuration;};
    profile-path = dot.options.path "profile installation path" {};
    dotship = {
      configuration = dot.options.module "central module and configuration derivation for profile" {apply = builder;};

      type = dot.options.enum ["home-manager" "nixos" "darwin" "custom"] "config module class" {
        default = {
          nixos = "nixos";
          darwin = "darwin";
          windows = "nixos";
          linux = "home-manager";
        }.${os};
      };

      activator = dot.options.function.pathInStore "how to build activation script from derivation" {
        default = {
          inherit (activate) nixos darwin home-manager;
          custom = base: activate.custom base.dotship.activation.package (lib.getExe base.dotship.activation.package);
        }.${type};
      };

      args = dot.options.attrs.anything "arguments based to configuration" {};

      builder = dot.options.function.raw "convert modules to configurations" {
        default = {
          nixos = modules: flakes.nixos.lib.nixosSystem {specialArgs = args; modules = [modules];};
          darwin = modules: flakes.darwin.lib.darwinSystem {specialArgs = args; modules = [modules];};
          custom = modules: lib.evalModules {specialArgs = args; modules = [modules];};

          home-manager = modules: flake.withSystem system (
            {pkgs, ...}: flakes.home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              extraSpecialArgs = args;
              modules = [modules];
            }
          );
        }.${type};
      };
    };
  };

  config = {
    user = let
      users = {
        home-manager = name;
        nixos = "root";
        darwin = "root";
      };
    in
      lib.mkDefault (users.${type} or null);

    dotship = {
      args = {
        inherit dot flake node;  
        # NOTE Avoid fixpoint infinite recursion
        profile = {
          inherit name;
          config = {inherit (config) dotship;};
        };
      };

      configuration = modules.${type} or {
        options.dotship.activation-package = dot.options.package "final package for custom profile" {};
      };
    };
  };
}
