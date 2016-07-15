module jeff.main;

import vibe.core.core;
import std.experimental.logger;
import std.stdio,
       std.format;

import dscord.core;

class JeffBot : Bot {
  immutable Snowflake owner = 80351110224678912;

  this(string token) {
    BotConfig bc;
    bc.token = token;
    bc.cmdPrefix = "";
    bc.lvlGetter = (u) => (u.id == this.owner) ? 100 : 0;
    super(bc, LogLevel.trace);

    // Add some plugins
    this.dynamicLoadPlugin("plugins/jeffcore/libjeffcore.so", null);
    this.dynamicLoadPlugin("plugins/utils/libutils.so", null);
    this.dynamicLoadPlugin("plugins/msglog/libmsglog.so", null);
    this.dynamicLoadPlugin("plugins/memes/libmemes.so", null);
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
