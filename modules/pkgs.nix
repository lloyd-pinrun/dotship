{
  config,
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    attrValues
    elem
    flip
    getExe
    getName
    importJSON
    literalExpression
    mkIf
    mkOption
    pipe
    toList
    types
    ;

  cfg = config.dotship.pkgs;
in {
  options.dotship.pkgs = {
    allowUnfree = mkOption {
      type = types.listOf types.str;
      default = [];
      example = literalExpression "[ \"unfree-package\" ]";
    };

    config = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      example = literalExpression ''
        { allowUnfreePredicate = true; }
      '';
      description = "nixpkgs configuration";
    };
  };

  config.dotship.pkgs.config = mkIf (cfg.allowUnfree != []) {
    allowUnfreePredicate = pkg: elem (getName pkg) cfg.allowUnfree;
  };

  config.perSystem = {
    pkgs,
    system,
    ...
  }: {
    options.dotship.pkgs.pkgs = mkOption {};

    config.dotship.pkgs.pkgs = pkgs;
    config._module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      inherit (config.dotship.pkgs) config;

      overlays =
        attrValues inputs.self.overlays
        ++ toList (final: _: {
          fromYAML = flip pipe [
            (file: "${final.yq}/bin/yq '.' ${file} > $out")
            (final.runCommand "from-yaml" {})
            importJSON
          ];

          execBash = cmd: [(getExe final.bash) "-c" cmd];
          execFish = cmd: [(getExe final.fish) "--command" cmd];

          wrapProgram = srcs: name: exe: args: overrides:
            final.symlinkJoin ({
                inherit name;
                buildInputs = [final.makeWrapper];
                paths = toList srcs;
                postBuild =
                  if name == exe
                  then "wrapProgram \"$out/bin/${exe}\" ${args}"
                  else "makeWrapper \"$out/bin/${exe}\" \"$out/bin/${name}\" ${args}";
                meta.minProgram = name;
              }
              // overrides);

          wrapFlags = pkg: args: final.wrapProgram pkg pkg.name pkg.name args {};
        });
    };
  };
}
