flake @ {
  dot,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.dotship) sudoer users;
  inherit (config.dotship.deploy) nodes;
  inherit (config.dotship.deploy.dotship) flakes modules;
in {
  imports = [./opentofu.nix];

  options.dotship.deploy = dot.options.submodule "deploy-rs" {
    imports = [./generic.nix];

    options = {
      nodes = dot.options.submoduleWith "nodes to deploy profiles to" {inherit flake;} ./node.nix;

      dotship.flakes = {
        deploy = dot.options.flake inputs "deploy-rs" {};
        nixos = dot.options.flake inputs "nixpkgs" {};
        darwin = dot.options.flake inputs "nix-darwin" {};
        home-manager = dot.options.flake inputs "home-manager" {};
        anywhere = dot.options.flake inputs "nixos-anywhere" {};
        disko = dot.options.flake inputs "disko" {};
      };

      dotship.modules = {
        home-manager = dot.options.module "home-manager modules" {};
        nixos = dot.options.module "nixos modules" {};
        darwin = dot.options.module "nix-darwin modules" {};
        system = dot.options.module "shared modules for system deployment (e.g. nixos, darwin)" {};
        shared = dot.options.module "shared modules for all deployments (including home-manager)" {};
      };
    };

    config = {
      dotship.modules = let
        hostnameModule = {node, ...}: {networking.hostName = node.config.hostname;};
      in {
        shared = {pkgs, ...}: {
          # NOTE: must instantiate within module; can't supply specialArgs because deploy-rs eagerly evaluates
          _module.args.perSystem = flake.withSystem pkgs.stdenv.hostPlatform.system lib.id;
        };

        home-manager = {profile, ...}: {
          imports = [modules.shared];
          config = lib.mkIf (profile.config.dotship.type == "home-manager") {
            home.username = lib.mkDefault profile.name;
          };
        };

        system = systemConfiguration @ {
          node,
          perSystem,
          profile,
          ...
        }: {
          imports = [modules.shared];
          nixpkgs.hostPlatform = node.config.dotship.system;
          home-manager = lib.mkIf (flakes.home-manager != null) {
            extraSpecialArgs = {inherit dot flake node perSystem profile systemConfiguration;};
            sharedModules = [modules.home-manager];
            users = builtins.mapAttrs (username: _: {home.username = lib.mkDefault username;}) users;
          };
        };

        nixos = lib.mkMerge [
          {
            imports = [hostnameModule modules.system];
            users.users = lib.flip builtins.mapAttrs users (username: user: {
              isNormalUser = true;
              home = "/home/${username}";
              description = user.name;
              extraGroups = ["tty"] ++ lib.optional (username == sudoer.username) "wheel";
            });
          }
          (lib.mkIf (flakes.disko != null) flakes.disko.nixosModules.default)
          (lib.mkIf (flakes.home-manager != null) ({utils, ...}: {
            imports = [flakes.home-manager.nixosModules.home-manager];
            home-manager.extraSpecialArgs = {inherit utils;};
          }))
        ];

        darwin = lib.mkMerge [
          {
            imports = [hostnameModule modules.system];
            users.users = lib.flip builtins.mapAttrs users (username: user: {
              home = "/Users/${username}";
              description = user.name;
            });
          }
          (lib.mkIf (flakes.home-manager != null) flakes.home-manager.darwinModules.home-manager)
        ];
      };
    };
  };

  config = let
    typeNodes = type: let
      isType = lib.filterAttrs (_: profile: profile.dotship.type == type);
      typeProfiles = funs: node: lib.pipe node.profiles ([isType builtins.attrValues] ++ funs);
    in
      lib.pipe nodes [
        # TODO:
        #   What happens if there are multiple "system"-type configurations?
        #   https://github.com/schradert/canivete/trunk/modules/deploy/default.nix#L103
        (lib.filterAttrs (_: typeProfiles [builtins.length (len: len == 1)]))
        (builtins.mapAttrs (_: typeProfiles [builtins.head (lib.genAttrFromPath ["dotship" "configuratiuon"])]))
      ];

    nixosConfigurations = typeNodes "nixos";
    darwinConfigurations = typeNodes "darwin";
    homeManagerConfigurations = typeNodes "home-manager";
  in
    lib.mkIf (nodes != {}) {
      flake = lib.mkMerge [
        {deploy = lib.filterAttrsRecursive (name: value: name != "dotship" && value != null) config.dotship.deploy;}
        (lib.mkIf (nixosConfigurations != {}) {inherit nixosConfigurations;})
        (lib.mkIf (darwinConfigurations != {}) {inherit darwinConfigurations;})
        (lib.mkIf (homeManagerConfigurations != {}) {inherit homeManagerConfigurations;})
      ];

      perSystem = {system, ...}: {
        checks = flakes.deploy.lib.${system}.deployChecks inputs.self.deploy;
        dotship.devenv.shells.default.packages = [flakes.deploy.packages.${system}.default];
      };
    };
}
