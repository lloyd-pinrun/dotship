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
  config.perSystem = {
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
  };
  config.flake.overlays.canivete = final: prev: {
    fromYAML = flip pipe [
      (file: "${final.yq}/bin/yq '.' ${file} > $out")
      (final.runCommand "from-yaml" {})
      importJSON
    ];
    execBash = cmd: [(getExe final.bash) "-c" cmd];
    wrapProgram = srcs: name: exe: args: overrides:
      final.symlinkJoin ({
          inherit name;
          buildInputs = [final.makeWrapper];
          paths = toList srcs;
          postBuild =
            if name == exe
            then "wrapProgram \"$out/bin/${exe}\" ${args}"
            else "makeWrapper \"$out/bin/${exe}\" \"$out/bin/${name}\" ${args}";
          meta.mainProgram = name;
        }
        // overrides);
    wrapFlags = pkg: args: final.wrapProgram pkg pkg.name pkg.name args {};

    # Patch underlying flake source tree
    # NOTE Adapted from https://discourse.nixos.org/t/apply-a-patch-to-an-input-flake/36904
    applyPatches = {
      name,
      src,
      patches,
      lockFileEntries ? {},
    }: let
      # Patched flake source
      patched =
        (prev.applyPatches {
          inherit name src;
          patches = forEach patches (patch:
            if isAttrs patch
            then prev.fetchpatch2 patch
            else patch);
        })
        .overrideAttrs (_: old: {
          outputs = ["out" "narHash"];
          installPhase = ''
            ${old.installPhase}
            ${getExe prev.nix} \
              --extra-experimental-features nix-command \
              --offline \
              hash path ./ \
              > $narHash
          '';
        });

      # New lock file
      lockFile = let
        lockFilePath = "${patched.outPath}/flake.lock";
        lockFileExists = pathExists lockFilePath;
        original = importJSON lockFilePath;
        root = ifElse lockFileExists original.root "root";
        nodes = ifElse lockFileExists (mergeAttrs original.nodes lockFileEntries) {root = {};};
      in
        builtins.unsafeDiscardStringContext (generators.toJSON {} {inherit root nodes;});

      # New flake object
      flake = {
        inherit (patched) outPath;
        narHash = fileContents patched.narHash;
      };
    in
      (import "${inputs.call-flake}/call-flake.nix") lockFile flake "";
  };
}
