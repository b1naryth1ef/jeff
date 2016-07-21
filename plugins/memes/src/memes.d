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
    e.msg.reply(".").after(1.seconds).edit("..").after(1.seconds)
      .edit("...").after(2.seconds).edit("no");
  }

  @Command("is clockwork good yet")
  void clockwork(CommandEvent e) {
    e.msg.reply("LOL! No.");
  }

  @Command("is rhino a nerd")
  void rhino(CommandEvent e) {
    e.msg.reply("Y").after(250.msecs).reply("E").after(250.msecs)
      .reply("S").after(250.msecs).reply(".");
  }
}

extern (C) Plugin create() {
  return new MemesPlugin;
}
