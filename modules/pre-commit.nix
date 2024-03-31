{inputs, ...}: {
  imports = [inputs.pre-commit.flakeModule];
  perSystem = {config, ...}: {
    devShells.pre-commit = config.pre-commit.devShell;
    pre-commit.settings.default_stages = ["push" "manual"];
    pre-commit.settings.hooks.alejandra.enable = true;
  };
}
