{
  dotlib,
  inputs,
  ...
}: {
  options.perSystem = inputs.flake-parts.lib.mkPerSystemOption (_: {
    options.dotship.languages = {
      # -- enabled by default --
      # keep-sorted start
      nix.enable = dotlib.options.enabled "tools for nix development" {};
      shell.enable = dotlib.options.enabled "tools for shell development" {};
      # keep-sorted end

      # -- disabled by default --
      # keep-sorted start
      elixir.enable = dotlib.options.enable "tools for elixier development" {};
      erlang.enable = dotlib.options.enable "tools for erlang development" {};
      lua.enable = dotlib.options.enable "tools for lua development" {};
      python.enable = dotlib.options.enable "tools for python development" {};
      rust.enable = dotlib.options.enable "tools for rust development" {};
      # keep-sorted end
    };
  });
}
