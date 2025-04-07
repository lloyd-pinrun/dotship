{
  config,
  inputs,
  ...
}: let
  inherit (config.canivete.meta.people) me;
  inherit (inputs.sops-nix) darwinModules homeManagerModules nixosModules;
  getFilepathHomeRelative = home: pkgs: let
    directoryConfig =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "Library/Application Support"
      else ".config";
  in "${home}/${directoryConfig}/sops/age/keys.txt";
  # TODO should I use age.sshKeyPaths + age.generateKey
  sharedSopsModule = {perSystem, ...}: {
    sops.defaultSopsFile = inputs.self + "/" + perSystem.config.canivete.sops.default;
  };
in {
  canivete.deploy.canivete.modules = {
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
    darwin = {pkgs, ...}: {
      imports = [sharedSopsModule darwinModules.sops];
      sops.age.keyFile = getFilepathHomeRelative "/Users/${me}" pkgs;
    };
  };
  perSystem = {
    canivete,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkEnableOption mkIf mkOption mkPackageOption readFile types;
    inherit (config.canivete) sops;
  in {
    imports = [./opentofu.nix];
    options.canivete.sops = {
      enable = mkEnableOption "sops" // {default = inputs ? sops-nix;};
      package = mkPackageOption pkgs "sops" {};
      directory = mkOption {
        type = types.str;
        default = ".canivete/sops";
        description = "Path relative to project root to store SOPS secrets";
      };
      default = mkOption {
        type = types.str;
        default = "default.yaml";
        description = "Path relative to sops directory for storing SOPS secrets by default";
        apply = canivete.prefix sops.directory;
      };
      scripts.setup = mkOption {
        type = types.package;
        default = pkgs.writeShellApplication {
          name = "sops-setup";
          runtimeInputs = with pkgs; [openssh age ssh-to-age gum];
          runtimeEnv.CANIVETE_SOPS_AGE_KEY_FILE = getFilepathHomeRelative pkgs;
          text = readFile ./setup.sh;
        };
      };
    };
    config.canivete = mkIf sops.enable {
      devShells.shells.default.packages = [sops.package];
      just.recipes."sops-setup *ARGS" = "nix run .#canivete.$(nix eval --raw --impure --expr \"builtins.currentSystem\").sops.scripts.setup \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}";
      pre-commit.settings.excludes = ["${sops.directory}/.+"];
    };
  };
}
