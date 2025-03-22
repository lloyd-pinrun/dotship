{
  config,
  inputs,
  ...
}: let
  inherit (config.canivete.meta.people) me;
  filepathConfigRelative = "sops/age/keys.txt";
  getFilepathHomeRelative = home: pkgs: let
    directoryConfig =
      if pkgs.stdenv.isDarwin
      then "Library/Application Support"
      else ".config";
  in "${home}/${directoryConfig}/${filepathConfigRelative}";
in {
  canivete.deploy.canivete.modules = {
    home-manager = {
      config,
      pkgs,
      ...
    }: {
      imports = [inputs.sops-nix.homeManagerModules.sops];
      # TODO should I use age.sshKeyPaths + age.generateKey
      sops.age.keyFile = getFilepathHomeRelative config.home.username pkgs;
      sops.defaultSopsFile = inputs.self + "/.canivete/sops/default.yaml";
    };
    nixos = {
      config,
      pkgs,
      ...
    }: {
      imports = [inputs.sops-nix.nixosModules.sops];
      # TODO should I use age.sshKeyPaths + age.generateKey
      sops.age.keyFile = getFilepathHomeRelative config.users.users.${me}.home pkgs;
      sops.defaultSopsFile = inputs.self + "/.canivete/sops/default.yaml";
    };
  };
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkEnableOption mkIf mkOption mkPackageOption readFile types;
  in {
    imports = [./opentofu.nix];
    options.canivete.sops = {
      enable = mkEnableOption "sops" // {default = inputs ? sops-nix;};
      package = mkPackageOption pkgs "sops" {};
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
    config.canivete = mkIf config.canivete.sops.enable {
      devShells.shells.default.packages = [config.canivete.sops.package];
      just.recipes."sops-setup *ARGS" = "nix run .#canivete.$(nix eval --raw --impure --expr \"builtins.currentSystem\").sops.scripts.setup \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}";
      pre-commit.settings.excludes = [".canivete/sops/.+"];
    };
  };
}
