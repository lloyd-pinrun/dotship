{
  config,
  nix,
  ...
}:
with nix; let
  userSubmodule = submodule {
    options.name = mkOption {
      type = str;
      description = "The name of the user to default to in all contexts";
      example = "John Doe";
    };
    options.accounts = mkOption {
      type = attrsOf str;
      description = "Mapping of external program name to user account name on it";
      example.github = "my-username";
      default = {};
    };
    options.profiles = mkOption {
      type = attrsOf (submodule {
        options.email = mkOption {
          type = str;
          description = "The email to associate with the user in this profile";
          example = "me@123.com";
        };
      });
    };
  };
in {
  options.canivete.people = mkOption {
    type = submodule {
      options.users = mkOption {
        type = attrsOf userSubmodule;
        description = "All of the users to create configurations for";
      };
      options.me = mkOption {
        type = str;
        description = ''
          The name of the user that represents myself.
          This will be the admin user in all contexts.
        '';
      };
      options.my = mkOption {
        type = userSubmodule;
        description = "The user details associated with 'me'";
        default = with config.canivete.people; users.${me};
      };
    };
  };
}
