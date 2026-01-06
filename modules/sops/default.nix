{
  dotlib,
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.dotship) sops;
  inherit (config.dotship.vars) sudoer;
  inherit (inputs) sops-nix;

  getFilepathHomeRelative = home: pkgs: let
    configDir = dotlib.trivial.turnary pkgs.stdenv.hostPlatform.isDarwin "Library/Application Support" ".config";
  in "${home}/${configDir}/sops/age/keys.txt";
in {
  options.dotship.sops = {
    enable = dotlib.options.enable "sops" {default = inputs ? sops-nix;};
    directory = dotlib.options.str "path relative to project root to store sops secrets" {default = ".dotship/sops";};

    default = dotlib.options.str "path relative to sops directory for storing sops secrets by default in yaml" {
      default = "default.yaml";
      apply = dotlib.strings.prefix "${sops.directory}/";
    };
  };

  config = lib.mkIf sops.enable {
    dotship.deploy.dotship.modules = {
      shared.sops.defaultSopsFile = inputs.self + "/" + sops.default;

      home-manager = {
        config,
        pkgs,
        ...
      }: {
        imports = [sops-nix.homeManagerModules.sops];
        sops.age.keyFile = getFilepathHomeRelative config.home.homeDirectory pkgs;
      };

      nixos = {
        config,
        pkgs,
        ...
      }: {
        imports = [sops-nix.nixosModules.sops];
        sops.age.keyFile = getFilepathHomeRelative config.users.users.${sudoer.username}.home pkgs;
      };

      darwin = {pkgs, ...}: {
        imports = [sops-nix.darwinModules.sops];
        sops.age.keyFile = getFilepathHomeRelative "/Users/${sudoer.username}" pkgs;
      };
    };

    perSystem = {
      config,
      pkgs,
      ...
    }: {
      imports = [./opentofu.nix];

      options.dotship.sops = {
        package = lib.mkPackageOption pkgs "sops" {};

        scripts.setup = dotlib.options.package "bootstrap repository sops" {
          default = pkgs.writeShellApplication {
            name = "sops-setup";
            runtimeInputs = with pkgs; [openssh age ssh-to-age gum usage];
            runtimeEnv.DOTSHIP_SOPS_AGE_KEY_FILE = getFilepathHomeRelative pkgs;
            text = builtins ./setup.sh;
          };
        };
      };

      config.dotship.devenv.modules = [
        {
          packages = [config.dotship.sops.package];
          git-hooks.excludes = "${sops.directory}/.*";
          scripts.sops-setup.exec = "nix run .#dotship.$(nix eval --raw --impure --expr \"builtins.currentSystem\").sops.scripts.setup \"\${NIX_OPTIONS[@]}\" -- \"$@\"";
        }
      ];
    };
  };
}
