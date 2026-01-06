flake @ {
  dotlib,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.dotship) vars;

  inherit (config.dotship.deploy) targets;
  inherit (config.dotship.deploy.dotship) flakes modules;
in {
  imports = [./opentofu.nix];

  options.dotship.deploy = dotlib.options.submodule "deploy-rs" {
    imports = [./generic.nix];

    options = {
      targets = dotlib.options.attrs.submoduleWith "targets for deployment" {inherit flake;} ./target.nix;

      dotship = {
        flakes = {
          deploy = dotlib.options.flake inputs "deploy-rs" {};
          nixos = dotlib.options.flake inputs "nixos" {};
          darwin = dotlib.options.flake inputs "nix-darwin" {};
          home-manager = dotlib.options.flake inputs "home-manager" {};
          anywhere = dotlib.options.flake inputs "nixos-anywhere" {};
          disko = dotlib.options.flake inputs "disko" {};
          # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L23
        };

        modules = {
          nixos = dotlib.options.module "nixos modules" {};
          darwin = dotlib.options.module "nix-darwin modules" {};
          home-manager = dotlib.options.module "home-manager modules" {};
          system = dotlib.options.module "shared modules for system deployments (nixos & darwin)" {};
          shared = dotlib.options.module "shared modules for all deployments (home-manager)" {};
          # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L32
        };
      };
    };

    config.dotship.modules = let
      hostnameModule = {target, ...}: {networking.hostName = target.config.hostname;};
    in {
      shared = {pkgs, ...}: {
        # WARN: must instantiate within module (can't pass through `specialArgs` because `deploy-rs` eagerly evaluates)
        _module.args.perSystem = flake.withSystem pkgs.stdenv.hostplatform.system lib.id;
      };

      system = systemConfiguration @ {
        target,
        perSystem,
        profile,
        ...
      }: {
        imports = [modules.shared];
        nixpkgs.hostPlatform = target.config.dotship.system;

        home-manager = lib.mkIf (flakes.home-manager != null) {
          extraSpecialArgs = {inherit dotlib flake target perSystem profile systemConfiguration;};
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
        (lib.mkIf (dotlib.trivial.notNull flakes.disko) flakes.disko.nixosModules.default)
        (lib.mkIf (dotlib.trivial.notNull flakes.home-manager) ({utils, ...}: {
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
        (lib.mkIf (dotlib.trivial.notNull flakes.home-manager) ({utils, ...}: {
          imports = [flakes.home-manager.darwinModules.home-manager];
          home-manager.extraSpecialArgs = {inherit utils;};
        }))
      ];

      # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L83
    };
  };

  config = let
    inherit (dotlib) attrsets trivial;

    targetForType = type: let
      isType = lib.filterAttrs (_: profile: profile.dotship.type == type);
      profilesExist = target: target ? profiles;
      typeProfiles = funs: target: lib.pipe target.profiles ([isType builtins.attrValues] ++ funs);
    in
      lib.pipe targets [
        (lib.filterAttrs (_: profilesExist))
        # WARN: what happens if there are multiple "system"-type configurations?
        # TODO: track https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L103
        (lib.filterAttrs (_: typeProfiles [builtins.length (_length: _length == 1)]))
        (builtins.mapAttrs (_: typeProfiles [builtins.head (lib.getAttrFromPath ["dotship" "configuration"])]))
      ];

    nixosConfigurations = targetForType "nixos";
    darwinConfigurations = targetForType "darwin";
    homeManagerConfigurations = targetForType "home-manager";
    # MAYBE: introduce android https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/default.nix#L109
  in
    lib.mkIf (! attrsets.isEmpty targets) {
      flake = lib.mkMerge [
        {deploy = lib.filterAttrsRecursive (name: value: name != "dotship" && (! trivial.isNull value)) config.dotship.deploy;}
        (lib.mkIf (! attrsets.isEmpty nixosConfigurations) {inherit nixosConfigurations;})
        (lib.mkIf (! attrsets.isEmpty darwinConfigurations) {inherit darwinConfigurations;})
        (lib.mkIf (! attrsets.isEmpty homeManagerConfigurations) {inherit homeManagerConfigurations;})
      ];

      perSystem = {system, ...}: {
        checks = lib.mkIf (! dotlib.trivial.isNull flakes.deploy) (flakes.deploy.lib.${system}.deployChecks inputs.self.deploy);
        dotship.devenv.shells.default.packages = lib.optionals (! dotlib.trivial.isNull flakes.deploy) [flakes.deploy.packages.${system}.default];
      };
    };
}
