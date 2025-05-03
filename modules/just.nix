{inputs, ...}: {
  imports = [inputs.just.flakeModule];

  perSystem = {
    dotship,
    config,
    lib,
    ...
  }: let
    inherit (config) just;

    inherit
      (lib)
      mkEnableOption
      mkIf
      mkMerge
      ;
  in {
    options.dotship.just.enable = mkEnableOption "just command runner" // {default = true;};

    config = mkMerge [
      (mkIf config.dotship.just.enable {
        just.enable = true;
      })
      (mkIf (just.enable && config.dotship.devShells.enable) {
        dotship.devShells.shells.shared.inputsFrom = [just.devShell];
      })
    ];
  };
}
