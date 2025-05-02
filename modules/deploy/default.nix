flake @ {
  dotship,
  config,
  inputs,
  lib,
  withSystem,
  ...
}: let
  inherit
    (dotship.lib.options)
    mkFlakeOption
    mkListOption
    mkModuleOption
    mkNullableOption
    mkSystemOption
    ;

  inherit (config.dotship.meta) root users;
  inherit (config.dotship.deploy) hosts;
  inherit (config.dotship.deploy.dotship) flakes modules;

  inherit
    (lib)
    attrNames
    filterAttrsRecursive
    flip
    getExe
    mapAttrs
    mkDefault
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    types
    ;

  sshOpts = {
    options.args = mkListOption types.str {description = "SSH CLI args";};
    options.user = mkNullableOption types.str {description = "user to connect with";};
  };

  sudoOpts = {
    options.command = mkNullableOption types.str {description = "sudo command";};
    options.interactive = mkNullableOption types.bool {description = "interactive sudo";};
  };

  timeoutOpts = {
    options.activation = mkNullableOption types.int {description = "timeout for profile activation";};
    options.confirm = mkNullableOption types.int {description = "timeout for profile activation confirmation";};
  };

  genericOpts = {
    options = {
      remoteBuild = mkNullableOption types.bool {description = "remote build on target system";};
      ssh = mkOption {type = types.lazyAttrsOf (types.submodule sshOpts);};
      sudo = mkOption {type = types.lazyAttrsOf (types.submodule sudoOpts);};
      tempPath = mkNullableOption types.path {description = "Temporary file location for inotify watcher";};
      timeout = mkOption {type = types.lazyAttrsOf (types.submodule timeoutOpts);};
      user = mkNullableOption types.str {description = "User to deploy to";};
    };
  };

  profileOpts = profile @ {
    config,
    name,
    host,
    ...
  }: let
    inherit (config.dotship) activator builder configuration type;
    inherit (flakes.deploy.lib.${host.config.dotship.system}) activate;
    inherit (host.config.dotship) os system;
  in {
    imports = [genericOpts];

    options.path = mkOption {
      type = types.pathInStore;
      default = activator configuration;
      description = "path to activation script for the given derivation";
    };

    options.profilePath = mkNullableOption types.path {description = "profile installation path";};

    options.dotship = {
      type = mkOption {
        type = types.enum ["darwin" "home-manager" "nixos"];

        default =
          {
            linux = "home-manager";
            macos = "darwin";
            nixos = "nixos";
          }
          .${
            os
          };

        description = "configuration module class (type derivation)";
      };

      activator = mkOption {
        type = types.functionTo types.pathInStore;
        default = {inherit (activate) darwin nixos home-manager;}.${type};
        description = "How to build activation script for a derivation";
      };

      builder = mkOption {
        type = types.functionTo types.raw;

        default =
          {
            darwin = modules: flakes.darwin.lib.darwinSystem {modules = [modules];};
            home-manager = modules:
              withSystem system ({pkgs, ...}:
                flakes.home-manager.lib.homeManagerConfiguration {
                  inherit pkgs;
                  modules = [modules];
                });
            nixos = modules: flakes.nixos.lib.nixosSystem {modules = [modules];};
          }
          .${
            type
          };

        description = "convert modules to configurations";
      };

      configuration = mkOption {
        type = types.deferredModule;
        default = {};
        description = "central module and configuration derivation for profile";
        apply = builder;
      };

      opentofu = mkOption {
        type = types.deferredModule;
        default = {};
        description = "extra module to be injected in OpenTofu workspace for the host";
      };
    };

    config.user = mkDefault ({
        home-manager = name;
        nixos = "root";
      }.${
        type
      } or null);

    config.dotship.configuration.imports = [
      (withSystem system (perSystem: {_module.args = {inherit dotship flake host perSystem profile;};}))
      (modules.${
          type
        }
        or {
          options.dotship.activationPackage = mkOption {
            type = types.package;
            description = "Final package for custom profile";
          };
        })
      (optionalAttrs (type == "home-manager") {home.username = name;})
      (optionalAttrs (type != "custom") {nixpkgs.hostPlatform = system;})
    ];

    config.dotship.opentofu = {
      config,
      pkgs,
      ...
    }: let
      inherit (config.resource) null_resource;
      resource_name = "${type}_${host.name}_${name}";
    in {
      config = mkMerge [
        {
          data.external.${resource_name}.program = pkgs.execBash ''
            nix eval .#dotship.deploy.hosts.${host.name}.profiles.${name}.path.drvPath | ${getExe pkgs.jq} '{drvPath:.}'
          '';

          resource.null_resource.${resource_name} = {
            triggers.drvPath = "\${ data.external.${resource_name}.result.drvPath }";
            provisioner.local-exec.command = ''
              ${getExe flakes.deploy.packages.${pkgs.system}.default} --skip-checks .#\"${host.name}\".\"${name}\"";
            '';
          };
        }
        (mkIf (type == "nixos") {
          modules."${resource_name}_install" = mkMerge [
            {
              source = "${flakes.anywhere}//terraform/install";
              target_host = host.config.hostname;
              flake = ".#${host.name}";
            }
            (mkIf (flakes.disko == null) {phases = ["kexec" "install" "reboot"];})
            (mkIf (null_resource ? sops) {depends_on = ["null_resource.sops"];})
            (mkIf (host.name != root) {depends_on = ["module.nixos_${root}_system_install"];})
          ];
          data.external.${resource_name}.depends_on = ["module.${resource_name}_install"];
        })
      ];
    };
  };

  hostOpts = host @ {
    config,
    name,
    ...
  }: {
    imports = [genericOpts];

    options = {
      name = mkOption {
        type = types.str;
        default = name;
        description = "server/machine hostname";
      };

      profiles = {
        profiles = mkOption {
          type = types.lazyAttrsOf (types.submodule {
            imports = [profileOpts];
            _module.args = {inherit host;};
          });
          default = {};
          description = "all possible profiles to deploy on the host";
        };

        order = mkListOption (types.enum (attrNames config.profiles.profiles)) {description = "first profiles to deploy";};
      };

      dotship.os = mkOption {
        type = types.enum ["linux" "macos" "nixos"];
        default = "nixos";
        description = "host operating system";
      };

      dotship.system = mkSystemOption {
        default = {macos = "aarch64-darwin";}.${config.dotship.os} or "x86_64-linux";
      };
    };
  };
in {
  options.dotship.deploy = mkOption {
    type = types.submodule {
      imports = [genericOpts];

      options = {
        hosts = mkOption {
          type = types.lazyAttrsOf (types.submodule hostOpts);
          default = {};
          description = "Host to deploy profiles to";
        };

        dotship = {
          flakes = {
            anywhere = mkFlakeOption "nixos-anywhere" {};
            darwin = mkFlakeOption "nix-darwing" {};
            deploy = mkFlakeOption "deploy-rs" {};
            disko = mkFlakeOption "disko" {};
            home-manager = mkFlakeOption "home-manager" {};
            nixos = mkFlakeOption "nixpkgs" {};
          };

          modules = {
            darwin = mkModuleOption {};
            home-manager = mkModuleOption {};
            nixos = mkModuleOption {};
            shared = mkModuleOption {};
            system = mkModuleOption {};
          };
        };
      };

      config.dotship.modules = let
        hostnameModule = {host, ...}: {networking.hostName = host.config.name;};
      in {
        home-manager.imports = [modules.shared];

        system = mkMerge [
          modules.shared
          (mkIf (flakes.home-manager != null) (systemConfiguration: {
            home-manager.sharedModules = [
              {
                imports = [modules.home-manager];
                _module.args = {inherit systemConfiguration;};
              }
            ];

            home-manager.users = mapAttrs (username: _: {home = {inherit username;};}) users.users;
          }))
        ];

        nixos = mkMerge [
          {
            imports = [hostnameModule modules.system];

            users.users = flip mapAttrs users.users (username: person: {
              isNormalUser = true;
              home = "/home/" + username;
              description = person.name;
              extraGroups = ["tty"] ++ person.groups;
            });
          }

          (mkIf (flakes.disko != null) flakes.disko.nixosModules.default)
          (mkIf (flakes.home-manager != null) ({utils, ...}: {
            imports = [flakes.home-manager.nixosModules.home-manager];
            home-manager.sharedModules = [{_module.args = {inherit utils;};}];
          }))
        ];

        darwin = mkMerge [
          {imports = [hostnameModule modules.system];}
          (mkIf (flakes.home-manager != null) ({utils, ...}: {
            imports = [flakes.home-manager.darwinModules.home-manager];
            home-manager.sharedModules = [{_module.args = {inherit utils;};}];
          }))
        ];
      };
    };

    default = {};
    description = "Deployment with deploy-rs and nixos-anywhere";
  };

  config = let
    inherit
      (lib)
      attrValues
      filterAttrs
      flatten
      flip
      getAttr
      getAttrFromPath
      head
      length
      mapAttrs
      mapAttrsToList
      pipe
      ;

    typeHosts = type: let
      typeProfiles = funcs: host:
        pipe host.profiles (
          [
            (filterAttrs (_: profile: profile.dotship.type == type))
            attrValues
          ]
          ++ funcs
        );
    in
      pipe hosts [
        (filterAttrs (_: typeProfiles [length (l: l == 1)]))
        (mapAttrs (_: typeProfiles [head (getAttrFromPath ["dotship" "configuration"])]))
      ];

    nixosConfigurations = typeHosts "nixos";
    darwinConfigurations = typeHosts "darwin";
    homeManagerConfigurations = typeHosts "home-manager";
  in
    mkIf (hosts != {}) {
      flake = mkMerge [
        {deploy = filterAttrsRecursive (name: value: name != "dotship" && value != null) config.dotship.deploy;}
        (mkIf (nixosConfigurations != {}) {inherit nixosConfigurations;})
        (mkIf (darwinConfigurations != {}) {inherit darwinConfigurations;})
        (mkIf (homeManagerConfigurations != {}) {inherit homeManagerConfigurations;})
      ];

      perSystem = {system, ...}: {
        checks = flakes.deploy.lib.${system}.deployChecks inputs.self.deploy;
        dotship.opentofu.workspaces.deploy = {
          modules.imports = pipe hosts [
            (mapAttrsToList (
              _:
                flip pipe [
                  (getAttr "profiles")
                  (mapAttrsToList (
                    _:
                      getAttrFromPath ["dotship" "opentofu"]
                  ))
                ]
            ))
            flatten
          ];

          plugins = ["hashicorp/pull" "hashicorp/external"];
        };
      };
    };
}
