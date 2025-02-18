{
  perSystem = {
    lib,
    pkgs,
    ...
  }: {
    options.canivete.scripts = lib.mkOption {
      default = {};
      description = "Scripts!";
      type = with lib.types; attrsOf (coercedTo pathInStore (pkgs.writeShellScriptBin "canivete") package);
    };
    config.canivete.scripts = {
      utils = ./utils.sh;
      sops-encrypt = ./encrypt.sh;
      sops-setup = ./setup.sh;
    };
  };
}
