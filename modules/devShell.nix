{
  perSystem = {
    lib,
    pkgs,
    self',
    ...
  }: {
    devShells.default = pkgs.mkShell {
      inputsFrom = lib.attrValues (removeAttrs self'.devShells ["default"]);
    };
  };
}
