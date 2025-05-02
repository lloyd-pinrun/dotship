{ dotship, config, inputs, lib, ... }: {
  perSystem._module.args.dotship = dotship;

  _module.args.dotship = {
    lib = import (../lib.nix) { inherit config inputs lib; };
    vals = {
      sops = let
        inherit (config.dotship.sops) directory default;
      in {
        custom = file: attr: "ref+sops://${directory}/${file}${attr}+";
        default = attr: "ref+sops://${default}#/${attr}+";
      };

      tfstate = workspace: attr: "ref+tfstate://.dotship/opentofu/${workspace}/terraform.tfstate.dec/${attr}+";
    };
  };
}
