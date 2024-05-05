{
  config,
  inputs,
  nix,
  ...
}:
with nix; {
  # TODO options for overlays (from options.flake.overlays doesn't work?)
  # TODO nixpkgs config options
  options.canivete.pkgs.config = mkOption {
    type = attrsOf anything;
    default = {};
    description = "Nixpkgs configuration (i.e. allowUnfree, etc.)";
  };
  options.perSystem = mkPerSystemOption ({
    pkgs,
    system,
    ...
  }: {
    options.canivete.pkgs.pkgs = mkOption {};
    config.canivete.pkgs.pkgs = pkgs;
    config._module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      inherit (config.canivete.pkgs) config;
      overlays = attrValues inputs.self.overlays;
    };
  });
  config.flake.overlays.canivete = final: _: {
    fromYAML = flip pipe [
      (file: "${final.yq}/bin/yq '.' ${file} > $out")
      (final.runCommand "from-yaml" {})
      importJSON
    ];
    execBash = cmd: [(getExe final.bash) "-c" cmd];
  };
}
