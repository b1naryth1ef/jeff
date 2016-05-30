module jeff.plugins.core;

import std.format,
       std.conv,
       std.array;

import dscord.core,
       dscord.util.counter;

class CorePlugin : Plugin {
  Counter!string counter;

  this() {
    PluginConfig cfg;
    super(cfg);

    this.counter = new Counter!string;
  }

  override void load(Bot bot) {
    super.load(bot);

    // Track number of times we've seen each event
    this.bot.client.events.listenAll((name, value) {
      this.counter.tick(name);
    });
  }

  @Command("ping")
  void onPing(CommandEvent event) {
    event.msg.reply("PONG");
  }

  // Events stuff
  @Command("counts", "view event counters", "event", false, 1)
  void onEventStats(CommandEvent event) {
    ushort numEvents = 5;
    if (event.args.length >= 1) {
      numEvents = to!(ushort)(event.args[0]);
    }

    string[] parts;
    foreach (e; this.counter.mostCommon(numEvents)) {
      parts ~= format("%s: %s", e, this.counter.storage[e]);
    }

    event.msg.reply("```" ~ parts.join("\n") ~ "```");
  }

  @Command("show", "show stats on specific event", "event", false, 1)
  void onEvent(CommandEvent event) {
    if (event.args.length < 1) {
      event.msg.reply("Please pass an event to view");
      return;
    }

    auto eventName = event.args[0];
    if (!(eventName in this.counter.storage)) {
      event.msg.reply("I don't know about that event (yet)");
      return;
    }

    event.msg.reply(format("I've seen %s event a total of `%s` times!", eventName, this.counter.storage[eventName]));
  }
}
