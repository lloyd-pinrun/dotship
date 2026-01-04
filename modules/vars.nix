{dot, ...}: {
  options.dotship.vars = {
    domain = dot.options.str "deployment domain" {};

    sudoer = dot.options.submodule "primary super-user" ({config, ...}: let
      inherit (config) users sudoer;
    in {
      options.username = dot.options.enum (builtins.attrNames users) "the primary super-user's username" {example = "username";};
      options.settings = dot.options.raw "the settings associated with the primary super-user" {default = users.${sudoer.username};};
    });

    users = dot.options.attrs.submodule "all users to configure for deployment" {
      options.description = dot.options.str "the user's first & last name" {example = "Peter Griffin";};
      options.accounts = dot.options.attrs.str "mapping of external account names to the user" {example = {github = "pgriffin";};};

      options.profiles = dot.options.attrs.submodule "mapping of profile information to the user" {
        options.email = dot.options.email "the user's email for the profile" {};
        options.ssh-pub-key = dot.options.str "the user's public SSH key for the profile" {};
      };
    };
  };
}
