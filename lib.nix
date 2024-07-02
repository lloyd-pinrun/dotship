{
  flake-parts-lib,
  inputs,
  lib,
  ...
}:
with lib;
  fold recursiveUpdate {} [
    builtins
    flake-parts-lib
    lib
    types
    licenses
    {
      # Fileset collectors
      filesets = rec {
        # List absolute path of files in <root> that satisfy <f>
        filter = f: root:
          pipe root [
            builtins.readDir
            (filterAttrs f)
            attrNames
            (map (file: root + "/${file}"))
          ];
        # List directories in <root>
        dirs = filter (_: type: type == "directory");
        # List files in <root> that satisfy <f>
        files = f: filter (name: type: type == "regular" && f name type);
        # Recursively list all files in <_dirs> that satisfy <f>
        everything = f: let
          filesAndDirs = root: [
            (files f root)
            (map (everything f) (dirs root))
          ];
        in
          flip pipe [toList (map filesAndDirs) flatten];
        # Filter out <exclude> paths from "everything" in <roots>
        everythingBut = f: roots: exclude: filter (_path: all (prefix: ! path.hasPrefix prefix _path) exclude) (everything f roots);
        nix = {
          filter = name: _: builtins.match ".+\.nix$" name != null;
          files = files nix.filter;
          everything = everything nix.filter;
          everythingBut = everythingBut nix.filter;
        };
      };
    }
    rec {
      # Useful functions
      eval = arg: f: f arg;
      majorMinorVersion = flip pipe [splitVersion (sublist 0 2) (concatStringsSep ".") (replaceStrings ["."] [""])];
      functions.defaultArgs = flip pipe [
        functionArgs
        (filterAttrs (_: id))
        attrNames
      ];
      functions.nonDefaultArgs = f: removeAttrs (functionArgs f) (functions.defaultArgs f);

      # Common options
      mkOverrideOption = args: flip pipe [(mergeAttrs args) mkOption];
      mkEnabledOption = doc:
        mkOption {
          type = types.bool;
          default = true;
          example = false;
          description = "Whether to enable ${doc}";
        };
      mkModulesOption = mkOverrideOption {
        type = with types; attrsOf deferredModule;
        default = {};
      };
      mkSystemOption = args: mkOption ({type = types.enum (import inputs.systems);} // args);
      mkSubdomainOption = mkOverrideOption {
        type = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$";
        example = "my-TEST-subdomain1";
      };
      mkDomainOption = mkOverrideOption {
        type = types.strMatching "^([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-z]{2,10}$";
        example = "something.like.this";
      };
      mkEmailOption = mkOverrideOption {
        type = types.strMatching "^[a-zA-Z0-9][a-zA-Z0-9_.%+\-]{0,61}[a-zA-Z0-9]@([a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,10}$";
        example = "my_email-address+%@something.like.this";
      };
      mkLatestVersionOption = mkOverrideOption {
        type = types.str;
        default = "latest";
        example = "0.0.1";
        description = "Set the version. Defaults to null (i.e. latest)";
      };

      # Convenience utilities
      flatMap = f: flip pipe [(map f) flatten];
      mkApp = program: {
        inherit program;
        type = "app";
      };
      mkIfElse = condition: yes: no:
        mkMerge [
          (mkIf condition yes)
          (mkIf (!condition) no)
        ];
      mkUnless = condition: flip (mkIfElse condition);
      mkMergeTopLevel = names:
        flip pipe [
          (foldAttrs (this: those: [this] ++ those) [])
          (mapAttrs (_: mkMerge))
          (getAttrs names)
        ];

      # Patch underlying flake source tree
      # NOTE https://discourse.nixos.org/t/apply-a-patch-to-an-input-flake/36904
      applyPatches = {
        pkgs,
        name,
        src,
        patches,
        lockFileEntries ? {},
      }: let
        numOfPatches = length patches;

        patchedFlake = let
          patched =
            (pkgs.applyPatches {
              inherit name src;
              patches = forEach patches (patch: if isAttrs patch then pkgs.fetchpatch2 patch else patch);
            })
            .overrideAttrs (_: prevAttrs: {
              outputs = ["out" "narHash"];
              installPhase = concatStringsSep "\n" [
                prevAttrs.installPhase
                ''
                  ${getExe pkgs.nix} \
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
    }
  ]
