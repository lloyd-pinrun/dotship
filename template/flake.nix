{
  inputs.canivete.url = github:schradert/canivete;
  outputs = inputs:
    with inputs;
      canivete.lib.mkFlake {
        inherit inputs;
        # Any path added to `everything` will treat every matching .nix file recursively as a flake-parts module
        everything = [];
      } {
        # This is a flake-parts module with canivete options supported
      };
}
