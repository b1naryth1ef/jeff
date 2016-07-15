module memes;

import std.conv,
       std.format,
       std.datetime,
       std.array;

import dscord.core;

import vibe.core.core;

class MemesPlugin : Plugin {
  this() {
    auto opts = new PluginOptions;
    super(opts);
  }

  @Command("is kt good yet")
  void kt(CommandEvent e) {
    Message m = e.msg.reply(".");
    sleep(1.seconds);
    m.edit("..");
    sleep(1.seconds);
    m.edit("...");
    sleep(2.seconds);
    m.edit("no");
  }

  @Command("is clockwork good yet")
  void clockwork(CommandEvent e) {
    e.msg.reply("LOL! No.");
  }

  @Command("is rhino a nerd")
  void rhino(CommandEvent e) {
    e.msg.reply("Y");
    sleep(250.msecs);
    e.msg.reply("E");
    sleep(250.msecs);
    e.msg.reply("S");
    sleep(250.msecs);
    e.msg.reply(".");
  }
}

extern (C) Plugin create() {
  return new MemesPlugin;
}
