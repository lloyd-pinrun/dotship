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
          postBuild = "wrapProgram \"$out/bin/${exe}\" ${args}";
          meta.mainProgram = exe;
        }
        // overrides);

    # Patch underlying flake source tree
    # NOTE https://discourse.nixos.org/t/apply-a-patch-to-an-input-flake/36904
    applyPatches = {
      name,
      src,
      patches,
      lockFileEntries ? {},
    }: let
      numOfPatches = length patches;
      patchedFlake = let
        patched =
          (prev.applyPatches {
            inherit name src;
            patches = forEach patches (patch:
              if isAttrs patch
              then prev.fetchpatch2 patch
              else patch);
          })
          .overrideAttrs (_: prevAttrs: {
            outputs = ["out" "narHash"];
            installPhase = concatStringsSep "\n" [
              prevAttrs.installPhase
              ''
                ${getExe prev.nix} \
                  --extra-experimental-features nix-command \
                  --offline \
                  hash path ./ \
                  > $narHash
              ''
            ];
          });

        lockFilePath = "${patched.outPath}/flake.lock";

        lockFile = builtins.unsafeDiscardStringContext (generators.toJSON {} (
          if pathExists lockFilePath
          then let
            original = importJSON lockFilePath;
          in {
            inherit (original) root;
            nodes = original.nodes // lockFileEntries;
          }
          else {
            nodes.root = {};
            root = "root";
          }
        ));

        flake = {
          inherit (patched) outPath;
          narHash = fileContents patched.narHash;
        };
      in
        (import "${inputs.call-flake}/call-flake.nix") lockFile flake "";
    in
      if numOfPatches == 0
      then trace "applyPatches: skipping ${name}, no patches" src
      else trace "applyPatches: creating ${name}, number of patches: ${toString numOfPatches}" patchedFlake;
  };
}
