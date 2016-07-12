module utils;

import std.conv,
       std.format,
       std.datetime,
       std.array;

import dscord.core;

class UtilsPlugin : Plugin {
  JSONObjectProxy events;

  this() {
    auto opts = new PluginOptions;
    opts.useStorage = true;
    super(opts);
  }

  void load(Bot bot, PluginState state = null) {
    super.load(bot, state);
    this.events = this.storage.getProxy("events");
  }

  @Command("add", "add a calendar event", "cal", false, 1)
  void addCalendarEvent(CommandEvent e) {
    this.events[e.args[0]] = JSONValue(e.args[1].to!long);
    e.msg.reply("Ok, added event");
  }

  @Command("del", "delete a calendar event", "cal", false, 1)
  void delCalendarEvent(CommandEvent e) {
    // this.events.remove(e.args[0]);
  }

  @Command("until", "time until a calendar event", "cal", false, 0)
  void daysCalendarEvent(CommandEvent e) {
    if (!this.events.has(e.args[0])) {
      e.msg.reply(format("Unknown event `%s`", e.args[0]));
      return;
    }

    auto now = Clock.currTime(UTC());
    auto then = SysTime(unixTimeToStdTime(this.events[e.args[0]].integer));
    e.msg.reply(format("%s", then - now));
  }

  @Command("list", "list calendar events", "cal", false, 0)
  void listCalendarEvent(CommandEvent e) {
    string[] content;
    auto now = Clock.currTime(UTC());

    foreach (string k, ref v; this.events) {
      auto then = SysTime(unixTimeToStdTime(v.integer));
      content ~= format("%s: %s",
        k,
        then - now,
      );
    }
    e.msg.reply(format("Events: ```%s```", content.join("\n")));
  }
}

extern (C) Plugin create() {
  return new UtilsPlugin;
}
