flake @ {inputs, ...}: {
  perSystem = perSystem @ {
    dotship,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (builtins) listToAttrs;

    inherit (config.dotship) opentofu;

    inherit
      (lib)
      mkEnableOption
      mkDefault
      mkIf
      mkMerge
      mkOption
      nameValuePair
      types
      ;

    workspacesOpts = import ./workspaces.nix {inherit config dotship flake inputs lib perSystem pkgs;};
  in {
    options.dotship.opentofu = {
      enable = mkEnableOption "OpenTofu workspaces" // {default = inputs ? terranix;};

      script = mkOption {
        type = types.package;
        default = pkgs.writeShellApplication {
          name = "opentofu";
          runtimeInputs = with pkgs; [git gum jq vals yq];
          text = builtins.readFile ./opentufu.sh;
        };
      };

      sharedModules = mkOption {
        type = types.deferredModule;
        default = {};
      };

      workspaces = mkOption {
        type = types.lazyAttrsOf (types.submodule workspacesOpts);
        default = {};
        description = "OpenTofu workspaces";
      };
    };

    config = mkIf opentofu.enable {
      just.recipes = mkIf config.just.enable {
        "tofu *ARGS" = "nix run .#dotship.$(nix eval --raw --impure --expr \"builtins.currentSystem\").opentofu.script \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}";
      };

      dotship.opentofu.sharedModules = {workspaces, ...}: let
        inherit (workspaces.config) encryptedState plugins;
      in {
        variable.GIT_DIR.type = "string";
        terraform = mkMerge [
          {
            required_providers = let
              pluginToProvider = pkg: nameValuePair pkg.repo {inherit (pkg) source version;};
            in
              listToAttrs (map pluginToProvider plugins);
          }
          (mkIf encryptedState.enable {
            encryption = let
              method = "\${ method.aes_gcm.default }";
            in {
              key_provider.pdkdf2.passphrase = mkDefault encryptedState.passphrase;
              method.aes_gcm.default.keys = "\${ key_provider.pdkdf2.default }";

              state = {
                method = mkDefault method;
                fallback = mkDefault {inherit method;};
              };
              plan = {
                method = mkDefault method;
                fallback = mkDefault {inherit method;};
              };
            };
          })
        ];
      };
    };
  };
}
