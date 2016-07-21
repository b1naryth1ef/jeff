module events;

import std.conv,
       std.format,
       std.datetime,
       std.array;

import jeff.perms;
import dscord.core;

class EventsPlugin : Plugin {
  VibeJSON events;

  this() {
    auto opts = new PluginOptions;
    opts.useStorage = true;
    super(opts);
  }

  override void load(Bot bot, PluginState state = null) {
    super.load(bot, state);
    this.events = this.storage.ensureObject("events");
  }

  @Command("add")
  @CommandGroup("cal")
  @CommandDescription("add a calendar event")
  @CommandLevel(UserGroup.MOD)
  void addCalendarEvent(CommandEvent e) {
    this.events[e.args[0]] = VibeJSON(e.args[1].to!long);
    e.msg.replyf("Ok, added event %s", e.args[0]);
  }

  @Command("del")
  @CommandGroup("cal")
  @CommandDescription("delete a calendar event")
  @CommandLevel(UserGroup.MOD)
  void delCalendarEvent(CommandEvent e) {
    if (!(e.args[0] in this.events)) {
      e.msg.replyf("Unknown event %s", e.args[0]);
      return;
    }

    this.events.remove(e.args[0]);
    e.msg.replyf("Ok, removed event %s", e.args[0]);
  }

  @Command("until")
  @CommandGroup("cal")
  @CommandDescription("time until a calendar event")
  void daysCalendarEvent(CommandEvent e) {
    if (!(e.args[0] in this.events)) {
      e.msg.replyf("Unknown event %s", e.args[0]);
      return;
    }

    auto then = SysTime(unixTimeToStdTime(this.events[e.args[0]].get!int));
    e.msg.replyf("%s", then - Clock.currTime(UTC()));
  }

  @Command("list")
  @CommandGroup("cal")
  @CommandDescription("list calendar events")
  void listCalendarEvent(CommandEvent e) {
    string[] content;
    auto now = Clock.currTime(UTC());

    foreach (string k, ref v; this.events) {
      auto then = SysTime(unixTimeToStdTime(v.get!int));
      content ~= format("%s: %s", k, then - now);
    }

    e.msg.replyf("Events: ```%s```", content.join("\n"));
  }
}

extern (C) Plugin create() {
  return new EventsPlugin;
}
