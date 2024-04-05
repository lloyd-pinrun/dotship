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
  config.flake.overlays.fromYAML = _: prev: {
    fromYAML = flip pipe [
      (file: "${prev.yq}/bin/yq '.' ${file} > $out")
      (prev.runCommand "from-yaml" {})
      importJSON
    ];
  };
  config.perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      inherit (config.canivete.pkgs) config;
      overlays = attrValues inputs.self.overlays;
    };
  };
}
