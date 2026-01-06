target @ {
  dotlib,
  flake,
  config,
  name,
  ...
}: let
  inherit (config.dotship) os;
in {
  imports = [./generic.nix];

  options = {
    hostname = dotlib.options.str "server hostname" {default = name;};
    profiles = dotlib.options.attrs.submoduleWith "profiles available for deployment to target" {inherit flake target;} ./profile.nix;
    order = dotlib.options.list.enum (builtins.attrNames config.profiles) "order of profiles to deploy" {};

    dotship = {
      os = dotlib.options.enum ["nixos" "macos" "windows" "linux"] "target operating system" {default = "nixos";};
      system = dotlib.options.str "target architecture" {
        # MAYBE: introduce android support https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/deploy/node.nix#L15-L23
        default = {macos = "aarch64-darwin";}.${os} or "x86_64-linux";
      };
    };
  };
}
