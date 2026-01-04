{dot, ...}: {
  options.dotship = {
    users = dot.attrs.submodule "all users to configure" {
      options.name = dot.str "user's name to default to in all contexts" {example = "John Doe";};
      options.accounts = dot.attrs.str "mapping of external account names to the user" {};

      options.profiles = dot.options.attrs.submodule "mapping of profile information to the user" {
        options.email = dot.email "user profile email" {};
        options.ssh-pub-key = dot.str "public key for connecting to external services" {};
      };
    };

    sudoer = dot.submodule "the super-user to use in all contexts" (
      {config, ...}: let
        inherit (config) users sudoer;
      in {
        options.username = dot.enum (builtins.attrNames users) "the username of the super-user" {};
        options.config = dot.raw "the user config associated with the super-user" {default = users.${sudoer.username};};
      }
    );
  };
}
