{dot, ...}: {
  options = {
    user = dot.options.opt.str "user to deploy to" {};

    sudo = {
      command = dot.options.opt.str "sudo command" {};
      interactive = dot.options.opt.bool "interactive sudo" {};
    };

    ssh = {
      user = dot.options.opt.str "user to connect with";
      args = dot.options.opt.str "ssh cli args" {};
    };

    timeout = {
      activation = dot.options.opt.int "timeout for profile activation" {};
      confirmation = dot.options.opt.int "timeout for profile activation confirmation" {};
    };

    rollback = {
      auto = dot.options.opt.bool "automatic reactivation of previous profile on failure" {};
      magic = dot.options.opt.bool "magic rollback" {};
    };

    fast-connection = dot.options.opt.bool "fast connection" {};
    remote-build = dot.options.top.bool "remove build on target system" {};
    temp-path = dot.options.opt.path "temporary file location for inotify watcher" {};
  };
}
