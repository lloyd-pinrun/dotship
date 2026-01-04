{
  dot,
  inputs,
  ...
}: {
  options.perSystem = inputs.flake-parts.lib.mkPerSystemOption (_: {
    options.dotship.languages = {
      # -- enabled by default --
      # keep-sorted start
      nix.enable = dot.options.enabled "tools for nix development" {};
      shell.enable = dot.options.enabled "tools for shell development" {};
      # keep-sorted end

      # -- disabled by default --
      # keep-sorted start
      elixir.enable = dot.options.enable "tools for elixier development" {};
      erlang.enable = dot.options.enable "tools for erlang development" {};
      lua.enable = dot.options.enable "tools for lua development" {};
      python.enable = dot.options.enable "tools for python development" {};
      rust.enable = dot.options.enable "tools for rust development" {};
      # keep-sorted end
    };
  });
}
