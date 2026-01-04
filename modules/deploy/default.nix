flake @ {
  dot,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.dotship) vars;

  inherit (config.dotship.deploy) nodes;
  inherit (config.dotship.deploy.dotship) flakes modules;
in {
  imports = [./opentofu.nix];

  options.dotship.deploy = dot.options.submodule "deploy-rs" {
    imports = [./generic.nix];

    options = {
      nodes = dot.options.attrs.submoduleWith "target nodes for deployment" {inherit flake;} ./node.nix;

      dotship = {
        flakes = {
          deploy = dot.options.flake inputs "deploy-rs" {};
          nixos = dot.options.flake inputs "nixos" {};
          darwin = dot.options.flake inputs "nix-darwin" {};
          home-manager = dot.options.flake inputs "home-manager" {};
          anywhere = dot.options.flake inputs "nixos-anywhere" {};
          disko = dot.options.flake inputs "disko" {};
          # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L23
        };

        modules = {
          nixos = dot.options.module "nixos modules" {};
          darwin = dot.options.module "nix-darwin modules" {};
          home-manager = dot.options.module "home-manager modules" {};
          system = dot.options.module "shared modules for system deployments (nixos & darwin)" {};
          shared = dot.options.module "shared modules for all deployments (home-manager)" {};
          # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L32
        };
      };
    };

    config.dotship.modules = let
      hostnameModule = {node, ...}: {networking.hostName = node.config.hostname;};
    in {
      shared = {pkgs, ...}: {
        # WARN: must instantiate within module (can't pass through `specialArgs` because `deploy-rs` eagerly evaluates)
        _module.args.perSystem = flake.withSystem pkgs.stdenv.hostplatform.system lib.id;
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
          users = builtins.mapAttrs (username: _: {home.username = lib.mkDefault username;}) vars.users;
        };
      };

      home-manager = {profile, ...}: let
        inherit (profile) name;
        inherit (profile.config.dotship) type;
      in {
        imports = [modules.shared];
        config = lib.mkIf (type == "home-manager") {
          home.username = lib.mkDefault name;
        };
      };

      nixos = lib.mkMerge [
        {
          imports = [hostnameModule modules.system];
          users.users = lib.flip builtins.mapAttrs vars.users (username: user: {
            inherit (user) description;
            home = "/home/${username}";
            isNormalUser = true;
            extraGroups = lib.mkDefault ["tty"] ++ (lib.optionals (username == vars.sudoer.username) ["wheel"]);
          });
        }
        (lib.mkIf (dot.trivial.notNull flakes.disko) flakes.disko.nixosModules.default)
        (lib.mkIf (dot.trivial.notNull flakes.home-manager) ({utils, ...}: {
          imports = [flakes.home-manager.nixosModules.home-manager];
          home-manager.extraSpecialArgs = {inherit utils;};
        }))
      ];

      darwin = lib.mkMerge [
        {
          imports = [hostnameModule modules.system];
          users.users = lib.flip builtins.mapAttrs vars.users (username: user: {
            inherit (user) description;
            home = "/Users/${username}";
          });
        }
        (lib.mkIf (dot.trivial.notNull flakes.home-manager) ({utils, ...}: {
          imports = [flakes.home-manager.darwinModules.home-manager];
          home-manager.extraSpecialArgs = {inherit utils;};
        }))
      ];

      # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L83
    };
  };

  config = let
    inherit (dot) attrsets trivial;

    typeNodes = type: let
      isType = lib.filterAttrs (_: profile: profile.dotship.type == type);
      profilesExist = node: node ? profiles;
      typeProfiles = funs: node: lib.pipe node.profiles ([isType builtins.attrValues] ++ funs);
    in
      lib.pipe nodes [
        (lib.filterAttrs (_: profilesExist))
        # WARN: what happens if there are multiple "system"-type configurations?
        # TODO: track https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L103
        (lib.filterAttrs (_: typeProfiles [builtins.length (_length: _length == 1)]))
        (builtins.mapAttrs (_: typeProfiles [builtins.head (lib.getAttrFromPath ["dotship" "configuration"])]))
      ];

    nixosConfigurations = typeNodes "nixos";
    darwinConfigurations = typeNodes "darwin";
    homeManagerConfigurations = typeNodes "home-manager";
    # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L109
  in
    lib.mkIf (! attrsets.isEmpty nodes) {
      flake = lib.mkMerge [
        {deploy = lib.filterAttrsRecursive (name: value: name != "dotship" && (! trivial.isNull value)) config.dotship.deploy;}
        (lib.mkIf (! attrsets.isEmpty nixosConfigurations) {inherit nixosConfigurations;})
        (lib.mkIf (! attrsets.isEmpty darwinConfigurations) {inherit darwinConfigurations;})
        (lib.mkIf (! attrsets.isEmpty homeManagerConfigurations) {inherit homeManagerConfigurations;})
      ];

      perSystem = {system, ...}: {
        checks = lib.mkIf (! dot.trivial.isNull flakes.deploy) (flakes.deploy.lib.${system}.deployChecks inputs.self.deploy);
        dotship.devenv.shells.default.packages = lib.optionals (! dot.trivial.isNull flakes.deploy) [flakes.deploy.packages.${system}.default];
      };
    };
}
