{dotlib, ...}: {
  options = {
    sudo = {
      command = dotlib.options.opt.str "sudo command" {};
      interactive.enable = dotlib.options.opt.bool "interactive sudo" {};
    };

    ssh = {
      user = dotlib.options.opt.str "user to connect with" {};
      args = dotlib.options.opt.list.str "ssh cli args" {};
    };

    remote = {
      user = dotlib.options.opt.str "target user" {};
      build.enable = dotlib.options.opt.bool "remote build on target" {};
    };

    settings = {
      rollback = {
        auto.enable = dotlib.options.opt.bool "automatic reactivation of previous profile on failure" {};
        magic.enable = dotlib.options.opt.bool "magic rollback" {};
      };

      timeout = {
        activation = dotlib.options.opt.int "timeout for profile activation" {};
        confirmation = dotlib.options.opt.int "timeout for profile activation confirmation" {};
      };

      fast-connection.enable = dotlib.options.opt.bool "fast connection" {};
      temp-path = dotlib.options.opt.path "temporary file location for inotify watcher" {};
    };
  };
}
