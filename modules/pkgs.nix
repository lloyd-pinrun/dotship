{
  inputs,
  lib,
  ...
}:
with lib; {
  flake.overlays.fromYAML = _: prev: {
    fromYAML = flip pipe [
      (file: "${prev.yq}/bin/yq '.' ${file} > $out")
      (prev.runCommand "from-yaml" {})
      importJSON
    ];
  };
  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = attrValues inputs.self.overlays;
    };
  };
}
