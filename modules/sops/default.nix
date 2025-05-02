{
  dotship,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.dotship.meta.users) me;
  inherit (config.dotship.sops) directory default;

  inherit (dotship.lib.strings) prefix;
  inherit (dotship.lib.trivial) turnary;

  inherit
    (inputs.sops-nix)
    darwinModules
    homeManagerModules
    nixosModules
    ;

  inherit
    (lib)
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    readFile
    types
    ;

  getFilepathHomeRelative = home: pkgs: let
    configHome = turnary pkgs.stdenv.hostPlatform.isDarwin "Library/Application Support" ".config";
  in "${home}/${configHome}/sops/age/keys.txt";

  sharedSopsModule.sops.defaultSopsFile = inputs.self + "/" + default;
in {
  options.dotship.sops = {
    directory = mkOption {
      type = types.str;
      default = ".dotship/sops";
      description = "Path relative to project root to store SOPS secrets";
    };

    default = mkOption {
      type = types.str;
      default = "default.yaml";
      description = "Path relative to SOPS directory for storing SOPS secrets by default in YAML";
      apply = prefix "${directory}/";
    };
  };

  config.dotship.deploy.dotship.modules = {
    darwin = {pkgs, ...}: {
      imports = [sharedSopsModule darwinModules.sops];
      sops.age.keyFile = getFilepathHomeRelative "/Users/${me}" pkgs;
    };

    home-manager = {
      config,
      pkgs,
      ...
    }: {
      imports = [sharedSopsModule homeManagerModules.sops];
      sops.age.keyFile = getFilepathHomeRelative config.home.homeDirectory pkgs;
    };

    nixos = {
      config,
      pkgs,
      ...
    }: {
      imports = [sharedSopsModule nixosModules.sops];
      sops.age.keyFile = getFilepathHomeRelative config.users.users.${me}.home pkgs;
    };
  };

  config.perSystem = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.dotship) sops;
    inherit (pkgs) writeShellApplication;

    scriptsOpts = {
      options.setup = mkOption {
        type = types.package;
        default = writeShellApplication {
          name = "sops-setup";
          runtimeInputs = with pkgs; [openssh rage ssh-to-age gum];
          runtimeEnv.DOTSHIP_SOPS_AGE_KEY_FILE = getFilepathHomeRelative pkgs;
          text = readFile ./setup.sh;
        };
      };
    };
  in {
    options.dotship.sops = {
      enable = mkEnableOption "sops" // {default = inputs ? sops-nix;};
      package = mkPackageOption pkgs "sops" {};
      scripts = mkOption {
        type = types.lazyAttrsOf (types.submodule scriptsOpts);
        default = {};
      };
    };

    config.dotship = mkIf sops.enable {
      devShells.shells.default.packages = [sops.package];
      just.recipes."sops-setup *ARGS" = "nix run .#dotship.$(nix eval --raw --impure --expr \"builtins.currentSystem\").sops.scripts.setup \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}";
      pre-commit.settings.excludes = ["${directory}/.+"];
    };
  };
}
