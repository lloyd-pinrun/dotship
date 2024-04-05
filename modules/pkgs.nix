{
  config,
  inputs,
  lib,
  ...
}:
with lib; {
  options.canivete.pkgs.config = mkOption {
    type = with types; attrsOf anything;
    default = {};
    description = mdDoc "Nixpkgs configuration (i.e. allowUnfree, etc.)";
  };
  config.flake.overlays.canivete = final: _: {
    fromYAML = flip pipe [
      (file: "${final.yq}/bin/yq '.' ${file} > $out")
      (final.runCommand "from-yaml" {})
      importJSON
    ];
    execBash = cmd: [(getExe final.bash) "-c" cmd];
  };
  config.perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      inherit (config.canivete.pkgs) config;
      overlays = attrValues inputs.self.overlays;
    };
  };
}
