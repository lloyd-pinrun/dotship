{dotlib, ...}: {
  options = {
    sudo = {
      command = dotlib.options.nullable.str "sudo command" {};
      interactive.enable = dotlib.options.nullable.bool "interactive sudo" {};
    };

    ssh = {
      user = dotlib.options.nullable.str "user to connect with" {};
      args = dotlib.options.list.str "ssh cli args" {};
    };

    remote = {
      user = dotlib.options.nullable.str "target user" {};
      build.enable = dotlib.options.nullable.bool "remote build on target" {};
    };

    settings = {
      rollback = {
        auto.enable = dotlib.options.nullable.bool "automatic reactivation of previous profile on failure" {};
        magic.enable = dotlib.options.nullable.bool "magic rollback" {};
      };

      timeout = {
        activation = dotlib.options.nullable.int "timeout for profile activation" {};
        confirmation = dotlib.options.nullable.int "timeout for profile activation confirmation" {};
      };

      fast-connection.enable = dotlib.options.nullable.bool "fast connection" {};
      temp-path = dotlib.options.nullable.path "temporary file location for inotify watcher" {};
    };
  };
}
