module jeff.main;

import vibe.core.core;

import std.stdio,
       std.format,
       std.functional,
       std.experimental.logger;

import jeff.perms;

import dscord.core;

class JeffBot : Bot {
  immutable Snowflake owner = 80351110224678912;

  this(string token) {
    BotConfig bc;
    bc.token = token;
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

void main(string[] args) {
  if (args.length <= 1) {
    writefln("Usage: %s <token>", args[0]);
    return;
  }

  (new JeffBot(args[1])).run();
  runEventLoop();
}
