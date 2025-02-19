{
  canivete,
  config,
  inputs,
  lib,
  self,
  ...
}: let
  inherit (lib) getAttrFromPath mapAttrs mkOption types attrValues concatStringsSep pipe mapAttrsToList flip getAttr flatten mkMerge mkIf;
  inherit (types) attrsOf str;
  specialArgs = {
    inherit canivete;
    flake = {inherit self inputs config;};
  };
in {
  imports = [./options.nix];
  flake = let
    nodeAttr = getAttrFromPath ["profiles" "system" "raw"];
    nodes = type: mapAttrs (_: nodeAttr) config.canivete.deploy.${type}.nodes;
    nixosConfigurations = nodes "nixos";
    darwinConfigurations = nodes "darwin";
    nixOnDroidConfigurations = nodes "droid";
  in
    mkMerge [
      (mkIf (nixosConfigurations != {}) {inherit nixosConfigurations;})
      (mkIf (darwinConfigurations != {}) {inherit darwinConfigurations;})
      (mkIf (nixOnDroidConfigurations != {}) {inherit nixOnDroidConfigurations;})
    ];
  canivete.deploy = {
    system.modules.secrets = {
      options.canivete.secrets = mkOption {
        type = attrsOf str;
        description = "Map of terraform resource to attribute to generate a secret from in /run/secrets";
        default = {};
      };
    };
    nixos = {
      modules.home-manager = {
        perSystem,
        utils,
        ...
      }: {
        imports = [inputs.home-manager.nixosModules.home-manager];
        home-manager.extraSpecialArgs = specialArgs // {inherit perSystem utils;};
        home-manager.sharedModules = attrValues config.canivete.deploy.nixos.homeModules;
      };
      defaultSystem = "x86_64-linux";
      systemBuilder = inputs.nixpkgs.lib.nixosSystem;
      systemActivationCommands = let
        systemdFlags = concatStringsSep " " [
          "--collect --no-ask-password --pipe --quiet --same-dir --wait"
          "--setenv LOCALE_ARCHIVE --setenv NIXOS_INSTALL_BOOTLOADER="
          # Using the full 'nixos-rebuild-switch-to-configuration' name on server would fail to collect/cleanup
          "--service-type exec --unit nixos-switch"
        ];
      in [
        "sudo nix-env --profile /nix/var/nix/profiles/system --set \"$closure\""
        "sudo systemd-run ${systemdFlags} \"$closure/bin/switch-to-configuration\" switch"
      ];
    };
    darwin.defaultSystem = "aarch64-darwin";
    darwin.systemBuilder = inputs.nix-darwin.lib.darwinSystem;
    darwin.systemActivationCommands = ["sudo HOME=/var/root \"$closure/activate\""];
    droid = {
      # Unfortunately this still requires impure evaluation
      nixFlags = ["--impure"];
      defaultSystem = "aarch64-linux";
      systemBuilder = inputs.nix-on-droid.lib.nixOnDroidConfiguration;
      systemAttr = "build.activationPackage";
      systemActivationCommands = ["$closure/activate"];
      modules.home-manager = {
        home-manager.extraSpecialArgs = specialArgs;
        home-manager.sharedModules = attrValues config.canivete.deploy.droid.homeModules;
      };
    };
  };
  perSystem.canivete.opentofu.workspaces.deploy = {
    plugins = ["opentofu/null" "opentofu/external"];
    modules.default.imports = pipe config.canivete.deploy [
      (mapAttrsToList (_:
        flip pipe [
          (getAttr "nodes")
          (mapAttrsToList (_:
            flip pipe [
              (getAttr "profiles")
              (mapAttrsToList (_: getAttr "opentofu"))
            ]))
        ]))
      flatten
    ];
  };
}
