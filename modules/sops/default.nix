{inputs, ...}: let
  filepathConfigRelative = "sops/age/keys.txt";
  getFilepathHomeRelative = pkgs: let
    directoryConfig =
      if pkgs.stdenv.isDarwin
      then "Library/Application Support"
      else ".config";
  in "~/${directoryConfig}/${filepathConfigRelative}";
in {
  canivete.deploy.system.homeModules.sops = {pkgs, ...}: {
    imports = [inputs.sops-nix.homeManagerModules.sops];
    sops.age.keyFile = getFilepathHomeRelative pkgs;
  };
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkEnableOption mkIf mkOption mkPackageOption readFile types;
  in {
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
    config = mkIf (config.canivete.sops.enable && config.canivete.devShells.enable) {
      canivete.pre-commit.settings.excludes = [".canivete/sops/.+"];
      canivete.devShells.shells.default.packages = [config.canivete.sops.package];
      canivete.just.recipes."sops-setup *ARGS" = "nix run .#canivete.$(nix eval --raw --impure --expr \"builtins.currentSystem\").sops.scripts.setup \"\${NIX_OPTIONS[@]}\" -- {{ ARGS }}";
    };
  };
}
