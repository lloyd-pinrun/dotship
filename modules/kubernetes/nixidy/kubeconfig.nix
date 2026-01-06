{
  dotlib,
  flake,
  lib,
  nixidy,
  pkgs,
  ...
}: let
  inherit (flake.config.dotship.vars) root;
  inherit (nixidy.config) package;
in {
  options.build.scripts.kubeconfig = dotlib.options.package "connect command for cluster" {internal = true;};

  config.build.scripts.kubeconfig = pkgs.mkShellApplication {
    name = "kubeconfig";
    runtimeInputs = with pkgs; [openssh tinybox];

    # TODO: fix hardcoded values
    # TRACK: https://github.com/schradert/canivete/blob/38c1937c3ce88599338746bd21ae94234f265c54/modules/kubernetes/nixidy/kubeconfig.nix#L14
    text = ''
      export KUBECONFIG="$(mktemp)";
      trap 'rm -f "$KUBECONFIG"' EXIT
      ssh ${root} sudo ${lib.getExe package} kubectl config view --raw | \
        sed 's/127\.0\.0\.1/${root}/' \
        >"$KUBECONFIG"
    '';
  };
}
