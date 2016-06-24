module jeffcore;

import std.format,
       std.conv,
       std.array;

import dscord.core,
       dscord.util.emitter;

import jeff.util.counter;

import vibe.core.core : sleep;

class CorePlugin : Plugin {
  Counter!string counter;
  BaseEventListener listener;

  this() {
    PluginConfig cfg;
    super(cfg);

    this.counter = new Counter!string;
  }

  override void load(Bot bot) {
    super.load(bot);

    // Track number of times we've seen each event
    this.listener = this.bot.client.events.listenAll((name, value) {
      this.counter.tick(name);
    });
  }

	override void unload(Bot bot) {
    super.unload(bot);
    this.listener.unbind();
	}

  @Command("ping")
  void onPing(CommandEvent event) {
    event.msg.reply("pong");
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

  Plugin pluginCommand(CommandEvent e, string action) {
    if (e.args.length != 1) {
      e.msg.reply("Must provide a plugin name to " ~ action);
      throw new EmitterStop;
    }

    if ((e.args[0] in this.bot.plugins) is null) {
      e.msg.reply(format("Unknown plugin `%s`", e.args[0]));
      throw new EmitterStop;
    }

    return this.bot.plugins[e.args[0]];
  }

  @Command("reload", "reload a plugin", "plugin", false, 1)
  void onPluginReload(CommandEvent e) {
    auto plugin = this.pluginCommand(e, "reload");

    // Defer the reload to avoid being within the function stack of the DLL, or
    //  smashing our stack while we're in another event handler.
    e.event.defer({
      plugin = this.bot.dynamicReloadPlugin(plugin);
      e.msg.reply(format("Reloaded plugin `%s`", plugin.name));
    });
  }

  @Command("unload", "unload a plugin", "plugin", false, 1)
  void onPluginUnload(CommandEvent e) {
    auto plugin = this.pluginCommand(e, "unload");

    // Similar to above, defer unloading the plugin
    e.event.defer({
      // Send the message first or 'plugin' will nullref
      e.msg.reply(format("Unloaded plugin `%s`", plugin.name));
      this.bot.unloadPlugin(plugin);
    });
  }

  @Command("load", "load a plugin", "plugin", false, 1)
  void onPluginLoad(CommandEvent e) {
    if (e.args.length != 1) {
      e.msg.reply("Must provide a DLL path to load");
      return;
    }

    // Note: this is super unsafe, should always be owner-only
    auto plugin = this.bot.dynamicLoadPlugin(e.args[0]);
    e.msg.reply(format("Loaded plugin `%s`", plugin.name));
  }

  @Command("list", "list all plugins", "plugin", false, 1)
  void onPluginList(CommandEvent e) {
    e.msg.reply(format("Plugins: `%s`", this.bot.plugins.keys.join(", ")));
  }
}

extern (C) Plugin create() {
  return new CorePlugin;
}
