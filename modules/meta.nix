{
  dotship,
  config,
  lib,
  ...
}: let
  inherit (lib) literalExpression mkOption types;
  inherit (dotship.lib.options) mkListOption mkNullableOption;

  inherit (config.dotship) meta;

  accountOpts = {
    options = {
      email = mkNullableOption dotship.lib.types.email;
      name = mkNullableOption types.str;
    };
  };

  userOpts = {
    options = {
      description = mkOption {
        type = types.str;
        example = literalExpression "\"Homer Simpson\"";
        description = "The name of the user to default to in all context";
      };

      email = {
        primary =
          mkNullableOption dotship.lib.types.email
          // {
            example = literalExpression "\"home@the-simpsons.com\"";
          };
        aliases =
          mkListOption dotship.lib.types.email
          // {
            example = literalExpression "[ \"hsimpson@springfieldpower.com\" ]";
          };
      };

      accounts = mkOption {
        type = types.lazyAttrsOf (types.submodule accountOpts);
        default = {};
        example.github = literalExpression ''
          { email = "homer@the-simpsons.com"; name = "homer-simpson"; }
        '';
        description = "Mapping of external program username to the user's name";
      };
    };
  };
in {
  options.dotship.meta = {
    domain = mkOption {
      type = dotship.lib.types.domain;
      description = "Base domain for exposing nodes and services";
    };

    root = mkOption {
      type = types.str;
      description = "Name of node to treat as deployment root";
    };

    users = mkOption {
      type = types.submodule {
        options = {
          users = mkOption {
            type = types.lazyAttrsOf (types.submodule userOpts);
            description = "All users to create configuration for";
          };

          me = mkOption {
            type = types.str;
            description = ''
              The name of the user that represents myself.
              This will be the admin user in all contexts.
            '';
          };

          my = mkOption {
            type = types.submodule userOpts;
            description = "The user details associatged with 'me'";
            default = with meta.users; all.${me};
          };
        };
      };
    };
  };
  # TODO: does this work?
  config.dotship.schemas.schemas.dotship.dotship.children.meta.children = {
    inherit (config) domain root;
    inherit (config.users) me;
  };
}
