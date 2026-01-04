node @ {
  dot,
  flake,
  config,
  name,
  ...
}: {
  imports = [./generic.nix];
  options = {
    hostname = dot.options.str "server hostname" {default = name;};
    profiles = dot.options.attrs.submoduleWith "all possible profiles to deploy to node" {inherit flake node;} ./profile.nix;
    order = dot.options.list.enum (builtins.attrNames config.profiles) "order of profiles to deploy" {};
    dotship.os = dot.options.enum ["nixos" "macos" "windows" "linux"] "node operation system" {default = "nixos";};
    dotship.system = dot.options.str "node architecture" {
      default = {macos = "aarch64-darwin";}.${config.dotship.os} or "x86_64-linux";
    };
  };
}
