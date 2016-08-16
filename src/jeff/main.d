module jeff.main;

import vibe.core.core;

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
  );

  if (helpInfo.helpWanted) {
    return defaultGetoptPrinter("jeff is friendly", helpInfo.options);
  }

  config.load();

  if (!config.token) {
    writeln("Token is required to run");
    return;
  }

  (new JeffBot(config)).run();
  runEventLoop();
}
