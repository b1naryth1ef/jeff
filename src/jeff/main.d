module jeff.main;

import vibe.core.core;
import std.experimental.logger;
import std.stdio,
       std.format;

import dscord.core;

import jeff.plugins.core : CorePlugin;
import jeff.plugins.pickup : PickupPlugin;

class JeffBot : Bot {
  immutable Snowflake owner = 80351110224678912;

  this(string token) {
    BotConfig bc;
    bc.token = token;
    bc.cmdPrefix = "";
    bc.lvlGetter = (u) => (u.id == this.owner) ? 1 : 0;
    super(bc, LogLevel.info);

    // Add some plugins
    this.addPlugin(new CorePlugin);
    this.addPlugin(new PickupPlugin);
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
