{inputs, ...}: {
  imports = [inputs.pre-commit.flakeModule];
  perSystem.pre-commit.settings = {
    default_stages = ["push" "manual"];
    hooks.alejandra.enable = true;
  };
}
