{
  dot,
  config,
  inputs,
  lib,
  ...
}: {
  options.dotship.pkgs = dot.options.submodule "high-level pkgs configuration" ({config, ...}: {
    options.allowUnfree = dot.options.list.package "packages to ignore because unfree" {};
    options.config = dot.options.attrs.anything "nixpkgs configuration (e.g. allowUnfreePredicate, etc.)" {};
    options.overlays = dot.options.overlay "nixpkgs overlays" {};

    config = {
      config = lib.mkIf (config.allowUnfree != []) {
        allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.allowUnfree;
      };

      overlays = final: _: {
        dotship = final.writeShellApplication {
          name = "dotship";
          runtimeInputs = with final; [gum usage];
          text = builtins.readFile ./utils.sh;
        };

        fromYAML = dot.trivial.pipe' [
          (file: "${final.yq}/bin/yq '.' ${file} > $out")
          (final.runCommand "from-yaml" {})
          lib.importJSON
        ];

        execBash = cmd: [(lib.getExe final.bash) "-c" cmd];

        wrapProgram = _srcs: name: exe: args: overrides:
          final.symlinkJoin (
            {
              inherit name;
              buildInputs = [final.makeWrapper];
              postBuild = dot.trivial.turnary (name == exe) "wrapProgram \"$out/bin/${exe}\" ${args}" "makeWrapper \"$out/bin/${exe}\" \"$out/bin/${name}\" ${args}";
              meta.mainProgram = name;
            }
            // overrides
          );

        wrapFlags = pkg: args: final.wrapProgram pkg pkg.name pkg.name args {};

        patchOut = pkg: cmd:
          final.runCommand "${pkg.name}-patched" {} ''
            cp -a ${pkg} $out
            chmod -R u+w $out
            ${cmd}
          '';
      };
    };
  });

  config.perSystem = {
    pkgs,
    system,
    ...
  }: {
    options.dotship.pkgs.pkgs = dot.options.anything "exposes upstream packages to flake" {};

    config.dotship.pkgs.pkgs = pkgs;
    config._module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      inherit (config.dotship.pkgs) config;
      overlays = [config.dotship.pkgs.overlays];
    };
  };
}
