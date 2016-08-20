module jeff.config;

import std.conv,
       std.experimental.logger;

import dscord.types.all,
       dscord.util.storage;


class JeffConfig {
  int threads = 4;

  string token;
  ushort shard = 0;
  ushort numShards = 1;
  string configPath = "config.json";

  string prefix = "";
  Snowflake owner;
  LogLevel logLevel = LogLevel.info;
  int[Snowflake] levels;

  bool autoReload = false;

  void load() {
    Storage storage = new Storage(this.configPath);
    storage.load();

    this.token = storage.get!string("token", "");
    this.prefix = storage.get!string("prefix", "");
    this.autoReload = storage.get!bool("auto_reload", false);

    if (storage.has("sharding")) {
      this.shard = storage["sharding"]["shard"].get!ushort;
      this.numShards = storage["sharding"]["total"].get!ushort;
    }

    if (storage.has("owner_id")) {
      this.owner = storage["owner_id"].get!string.to!Snowflake;
    }

    if (storage.has("log_level")) {
      switch (storage["log_level"].get!string) {
        case "trace":
          this.logLevel = LogLevel.trace;
          break;
        case "info":
          this.logLevel = LogLevel.info;
          break;
        case "warning":
          this.logLevel = LogLevel.warning;
          break;
        case "off":
          this.logLevel = LogLevel.off;
          break;
        default:
          throw new Exception("Invalid log_level");
      }
    }

    if (storage.has("levels")) {
      foreach (string k, VibeJSON v; storage["levels"]) {
        this.levels[k.to!Snowflake] = v.get!int;
      }
    }
  }
}

