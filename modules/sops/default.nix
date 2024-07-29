{
  config,
  inputs,
  nix,
  ...
}:
with nix; let
  filepathConfigRelative = "sops/age/keys.txt";
  getFilepathHomeRelative = pkgs: let
    directoryConfig = if pkgs.stdenv.isDarwin then "Library/Application Support" else ".config";
  in "~/${directoryConfig}/${filepathConfigRelative}";
in {
  canivete.devShell.packages = [pkgs.sops];
  canivete.deploy.system.homeModules.sops = {pkgs, ...}: {
    imports = [inputs.sops-nix.homeManagerModules.sops];
    sops.age.keyFile = getFilepathHomeRelative pkgs;
  };
  perSystem = {config, pkgs, ...}: {
    options.canivete.sops = {
      encrypt = mkOption {
        type = package;
        description = "Script to set up sops in the repo";
      };
      setup = mkOption {
        type = package;
        description = "Script to set up sops in the repo";
      };
    };
    config.canivete = {
      scripts.sops-encrypt = ./encrypt.sh;
      scripts.sops-setup = ./setup.sh;
      sops.encrypt = let
        args = concatStringsSep " " [
          "--set age_key_file ${getFilepathHomeRelative pkgs}"
          "--prefix PATH : ${makeBinPath (with pkgs; [age openssh ssh-to-age])}"
        ];
      in pkgs.wrapProgram config.canivete.scripts.sops-encrypt.package "sops-encrypt" "sops-encrypt" args {};
      sops.setup = let
        args = "--prefix PATH : ${makeBinPath (with pkgs; [sops])}";
      in pkgs.wrapProgram config.canivete.scripts.sops-setup.package "sops-setup" "sops-setup" args {};
    };
  };
}
