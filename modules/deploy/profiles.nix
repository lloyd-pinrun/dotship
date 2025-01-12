node @ {
  name,
  canivete,
  lib,
  flake,
  type,
  options,
  config,
  withSystem,
  ...
}: let
  inherit (lib) mkOption types mkIf mkMerge attrValues mergeAttrs flip mapAttrs;
  inherit (types) attrsOf submodule str functionTo raw deferredModule listOf enum;
in {
  options.profiles = mkOption {
    default = {};
    type = attrsOf (submodule ({
      config,
      name,
      ...
    }: {
      imports = [./opentofu.nix];
      options = {
        attr = mkOption {type = str;};
        builder = mkOption {type = functionTo raw;};
        module = mkOption {type = deferredModule;};
        modules = canivete.mkModulesOption {};
        raw = mkOption {type = raw;};
        cmds = mkOption {type = listOf str;};
        sshProtocol = mkOption {
          type = enum ["ssh" "ssh-ng"];
          description = "Protocol for copying derivations and closures";
          default = "ssh-ng";
        };
        build.host = options.build.host // {default = config.build.host;};
        build.sshFlags = options.build.sshFlags // {default = config.build.sshFlags;};
        target.host = options.target.host // {default = config.target.host;};
        target.sshFlags = options.target.sshFlags // {default = config.target.sshFlags;};
      };
      config = {
        _module.args = {inherit canivete flake node type;};
        modules.self = config.module;
        modules.canivete = mkIf (name != "system") {options.canivete = node.config.profiles.system.raw.options.canivete;};
        raw = with config; builder modules;
      };
    }));
  };
  config = mkMerge [
    {
      profiles.system = {
        attr = type.config.systemAttr;
        cmds = type.config.systemActivationCommands;
        modules = mergeAttrs type.config.modules (
          if type.name != "droid"
          then {hostname.networking.hostName = name;}
          else {}
        );
        builder = modules:
          withSystem config.system (
            perSystem @ {pkgs, ...}: let
              _builder = type.config.systemBuilder;
              # Some tools call this extraSpecialArgs for some reason...
              argsKey =
                if type.name == "droid"
                then "extraSpecialArgs"
                else "specialArgs";
              args = {
                ${argsKey} = type.config.specialArgs // {inherit perSystem;};
                inherit pkgs;
                modules = attrValues modules;
              };
            in
              _builder args
          );
      };
    }
    {
      profiles = flip mapAttrs config.home (username: module: {
        inherit module;
        modules = mergeAttrs type.config.homeModules {username.home = {inherit username;};};
        attr = "home.activationPackage";
        builder = modules:
          withSystem config.system (
            perSystem @ {pkgs, ...}: let
              _builder = flake.inputs.home-manager.lib.homeManagerConfiguration;
              args = {
                inherit pkgs;
                extraSpecialArgs = {inherit flake canivete perSystem;};
                modules = attrValues modules;
              };
            in
              _builder args
          );
        cmds = ["\"$closure/activate\""];
        inherit (config.profiles.system) build target;
      });
    }
  ];
}
