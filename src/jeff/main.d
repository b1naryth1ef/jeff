module jeff.main;

import vibe.core.core,
       vibe.core.file;

import std.stdio,
       std.conv,
       std.file,
       std.getopt,
       std.format,
       std.functional,
       std.algorithm.searching,
       std.experimental.logger;

import jeff.perms,
       jeff.config;

import dscord.core;

class JeffBot : Bot {
  JeffConfig config;

  this(JeffConfig config) {
    this.config = config;

    BotConfig bc;
    bc.token = this.config.token;
    bc.shard = this.config.shard;
    bc.numShards = this.config.numShards;
    bc.cmdPrefix = this.config.prefix;
    bc.levelsEnabled = true;
    super(bc, this.config.logLevel);

    this.loadPlugins();
  }

  void loadPlugins() {
    foreach (path; dirEntries("plugins/", "*.so", SpanMode.depth, false)) {
      if (path.to!string.canFind(".dub")) continue;
      this.log.infof("Loading plugin %s", path);
      this.dynamicLoadPlugin(path, null);
    }

    // Watch plugins directory if we're auto reloading
    if (this.config.autoReload) {
      runTask(&this.pluginReloader, watchDirectory("plugins/"));
    }
  }

  void pluginReloader(DirectoryWatcher watch) {
    DirectoryChange[] changes;
    Plugin[string] pluginPaths;

    foreach (plugin; this.plugins.values) {
      pluginPaths[plugin.dynamicLibraryPath] = plugin;
    }

    while (true) {
      watch.readChanges(changes);

      foreach (change; changes) {
        string path = change.path.toString();
        if (path in pluginPaths) {
          if (change.type != DirectoryChangeType.removed) {
            this.log.infof("Detected change in %s, reloading plugin %s", path, pluginPaths[path]);
            try {
              pluginPaths[path] = this.dynamicReloadPlugin(pluginPaths[path]);
            } catch (Exception e) {
              this.log.warning("Failed to reload plugin %s: %s", pluginPaths[path], e.toString);
            }
          }
        }
      }
    }
  }

  override int getLevel(Role r) {
    if (r.id in this.config.levels) {
      return this.config.levels[r.id];
    }

    return 0;
  }

  override int getLevel(User u) {
    if (u.id == this.config.owner) {
      return int.max - 1;
    }

    // If we have it in the config
    if (u.id in this.config.levels) {
      return this.config.levels[u.id];
    }

    // If we have the mod plugin, use it for grabbing the group
    if ("mod.ModPlugin" in this.plugins) {
      auto obj = cast(UserGroupGetter)this.plugins["mod.ModPlugin"];
      return obj.getGroup(u);
    }

    return 0;
  }
}

void main(string[] rawargs) {
  JeffConfig config = new JeffConfig;

  auto helpInfo = getopt(
    rawargs,
    "token", "Authentication token for the bot account", &config.token,
    "shard", "Shard number to use when connecting", &config.shard,
    "num-shards", "Total number of shards active", &config.numShards,
    "config", "Path to the config file", &config.configPath,
    "threads", "Number of worker threads to run", &config.threads,
  );

  if (helpInfo.helpWanted) {
    return defaultGetoptPrinter("jeff is friendly", helpInfo.options);
  }

  config.load();

  if (config.token == "") {
    writeln("Token is required to run");
    return;
  }

  setupWorkerThreads(config.threads);

  (new JeffBot(config)).run();
  runEventLoop();
}
