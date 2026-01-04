{dot, ...}: {
  options = {
    sudo = {
      command = dot.options.opt.str "sudo command" {};
      interactive.enable = dot.options.opt.bool "interactive sudo" {};
    };

    ssh = {
      user = dot.options.opt.str "user to connect with";
      args = dot.options.opt.list.str "ssh cli args" {};
    };

    remote = {
      user = dot.options.opt.str "target user" {};
      build.enable = dot.options.opt.bool "remote build on target" {};
    };

    settings = {
      rollback = {
        auto.enable = dot.options.opt.bool "automatic reactivation of previous profile on failure" {};
        magic.enable = dot.options.opt.bool "magic rollback" {};
      };

      timeout = {
        activation = dot.options.opt.int "timeout for profile activation" {};
        confirmation = dot.options.opt.int "timeout for profile activation confirmation" {};
      };

      fast-connection.enable = dot.options.opt.bool "fast connection" {};
      temp-path = dot.options.opt.path "temporary file location for inotify watcher" {};
    };
  };
}
