{
  dotlib,
  config,
  ...
}: let
  inherit (config.dotship) vars;
in {
  options.dotship.vars = {
    domain = dotlib.options.str "deployment domain" {};

    sudoer = dotlib.options.submodule "primary super-user" ({config, ...}: let
      inherit (config) users sudoer;
    in {
      options.username = dotlib.options.enum (builtins.attrNames users) "the primary super-user's username" {example = "username";};
      options.settings = dotlib.options.raw "the settings associated with the primary super-user" {default = users.${sudoer.username};};
    });

    users = dotlib.options.attrs.submodule "all users to configure for deployment" ({name, ...}: {
      options.description = dotlib.options.str "the user's first & last name" {example = "Peter Griffin";};
      options.accounts = dotlib.options.attrs.str "mapping of external account names to the user" {example = {github = "pgriffin";};};

      options.profiles = dotlib.options.attrs.submodule "mapping of profile information to the user" {
        options.email = dotlib.options.email "the user's email for the profile" {default = "${name}@${vars.domain}";};
        options.ssh-pub-key = dotlib.options.str "the user's public SSH key for the profile" {};
      };
    });
  };
}
