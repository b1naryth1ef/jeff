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

  @Command("about")
  void onAboutCommand(CommandEvent event) {
    event.msg.reply("hi, im jeff by b1nzy :^)");
  }

  @Command("event stats")
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
}
