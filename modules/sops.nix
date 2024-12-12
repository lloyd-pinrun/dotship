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
  }: {
    options.canivete.sops.enable = lib.mkEnableOption "sops" // {default = inputs ? sops-nix;};
    config = lib.mkIf (config.canivete.sops.enable && config.canivete.devShells.enable) {
      canivete.devShells.shells.default.packages = [pkgs.sops];
    };
  };
}
