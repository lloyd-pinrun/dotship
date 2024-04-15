{
  config,
  nix,
  ...
}:
with nix; {
  flake.canivete = mergeAttrs config.canivete (mapAttrs (_: getAttr "canivete") config.allSystems);
}
