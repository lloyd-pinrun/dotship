{
  config,
  inputs,
  nix,
  ...
}:
with nix; {
  imports = [./nixos.nix ./darwin.nix ./droid.nix ./home.nix];
  options.canivete.deploy.system.modules = mkModulesOption {};
  config.flake.checks = mapAttrs (_: deployLib: deployLib.deployChecks inputs.self.deploy) inputs.deploy-rs.lib;
  config.flake.deploy = removeAttrs config.canivete.deploy ["nixos" "darwin" "droid" "home" "system"];
  config.canivete.deploy.system.modules.nix = {pkgs, ...}: {
    nix.extraOptions = "experimental-features = nix-command flakes";
    nix.package = pkgs.nixVersions.latest;
  };
  config.perSystem = {system, ...}: {
    apps.deploy = inputs.deploy-rs.apps.${system}.default;
    canivete.devShell.apps.deploy.script = "nix run .#deploy -- \"$@\"";
  };
}
