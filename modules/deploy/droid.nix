{
  config,
  inputs,
  nix,
  ...
}:
with nix; {
  options.canivete.deploy.droid = {
    modules = mkModulesOption {};
    nodes = mkOption {
      default = {};
      type = attrsOf (coercedTo deferredModule (module:
        inputs.nix-on-droid.lib.nixOnDroidConfiguration {
          modules = attrValues inputs.self.systemModules ++ attrValues inputs.self.droidModules ++ [module];
        })
      raw);
    };
  };
  config.canivete.deploy.droid.modules.default = {
    environment.etcBackupExtension = ".bak";
    home-manager.backupFileExtension = "hm-bak";
    home-manager.config = {
      imports = attrValues config.canivete.deploy.home.modules;
      home.username = "termux";
      home.userDirectory = "/data/data/com.termux.nix/files/home";
    };
    home-manager.useGlobalPkgs = true;
  };
}
