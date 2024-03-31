{
  inputs,
  lib,
  ...
}: {
  systems = with inputs; lib.mkDefault (import systems);
}
