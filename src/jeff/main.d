module jeff.main;

import vibe.core.core;

import std.stdio,
       std.getopt,
       std.format,
       std.functional,
       std.experimental.logger;

import jeff.perms;

import dscord.core;

class JeffBot : Bot {
  immutable Snowflake owner = 80351110224678912;

  this(CommandLineArgs args) {
    BotConfig bc;
    bc.token = args.token;
    bc.shard = args.shard;
    bc.numShards = args.numShards;
    bc.cmdPrefix = "";
    bc.lvlGetter = toDelegate(&this.levelGetter);
    super(bc, LogLevel.info);

    // Add some plugins
    this.dynamicLoadPlugin("plugins/mod/libmod.so", null);
    this.dynamicLoadPlugin("plugins/jeffcore/libjeffcore.so", null);
    this.dynamicLoadPlugin("plugins/events/libevents.so", null);
    this.dynamicLoadPlugin("plugins/msglog/libmsglog.so", null);
    this.dynamicLoadPlugin("plugins/memes/libmemes.so", null);
  }

  int levelGetter(User u) {
    if (u.id == this.owner) {
      return 10000;
    }

    auto obj = cast(UserGroupGetter)this.plugins["mod.ModPlugin"];
    return obj.getGroup(u);
  }
}

struct CommandLineArgs {
  string token;
  ushort shard = 0;
  ushort numShards = 1;
}

void main(string[] rawargs) {
  CommandLineArgs args;

  auto helpInfo = getopt(
    rawargs,
    "token", &args.token,
    "shard", &args.shard,
    "num-shards", &args.numShards
  );

  if (helpInfo.helpWanted) {
    return defaultGetoptPrinter("jeff is friendly", helpInfo.options);
  }

  if (!args.token) {
    writeln("Token is required to run");
    return;
  }

  (new JeffBot(args)).run();
  runEventLoop();
}
