module jeffcore;

import std.format,
       std.conv,
       std.array,
       std.algorithm.iteration;

import dscord.core,
       dscord.util.emitter;

import jeff.util.counter,
       jeff.util.queue;

import vibe.core.core : sleep;

static private struct MessageHeapItem {
  Snowflake id;
  Snowflake authorID;

  this(Message msg) {
    this.id = msg.id;
    this.authorID = msg.author.id;
  }
}

alias MessageHeap = SizedQueue!(MessageHeapItem);

class CorePlugin : Plugin {
  size_t messageHistoryCacheSize = 100;

  Counter!string counter;
  BaseEventListener listener;

  // Store of messages we've sent
  MessageHeap[Snowflake] msgHistory;

  this() {
    super();

    this.counter = new Counter!string;
  }

  override void load(Bot bot, PluginState state = null) {
    super.load(bot, state);

    // Track number of times we've seen each event
    this.listener = this.bot.client.events.listenAll((name, value) {
      this.counter.tick(name);
    });
  }

  override void unload(Bot bot) {
    super.unload(bot);
    this.listener.unbind();
  }

  // TODO: handle message delete and MessageHeap storage
  @Listener!MessageCreate()
  void onMessageCreate(MessageCreate event) {
    auto msg = event.message;

    // If the channel doesn't exist in our history cache, create a new heap for it
    if ((msg.channel.id in this.msgHistory) is null) {
      this.msgHistory[msg.channel.id] = new MessageHeap(this.messageHistoryCacheSize);
    // Otherwise its possible the history queue is full, so we should clear an item off
    } else if (this.msgHistory[msg.channel.id].full) {
      this.msgHistory[msg.channel.id].pop();
    }

    // Now place it on the queue
    this.msgHistory[msg.channel.id].push(MessageHeapItem(msg));
  }

  @Listener!MessageDelete()
  void onMessageDelete(MessageDelete event) {
    if ((event.channelID in this.msgHistory) is null) {
      return;
    }

    auto msgs = this.msgHistory[event.channelID].array.filter!(msg => msg.id != event.id);
    this.msgHistory[event.channelID].clear();
    assert(this.msgHistory[event.channelID].push(msgs.array));
  }

  // TODO: handle guilddelete/channeldelete for msg history

  @Command("ping")
  void onPing(CommandEvent event) {
    event.msg.reply("pong");
  }

  @Command("clean", "clean previously sent messages", "", false, 1)
  void onClean(CommandEvent event) {
    if ((event.msg.channel.id in this.msgHistory) is null || this.msgHistory[event.msg.channel.id].empty) {
      auto msg = event.msg.reply("No previously sent messages in this channel!");
      sleep(3.seconds);
      msg.del();
      return;
    }

    // Grab all message ids we created from the history
    auto msgs = this.msgHistory[event.msg.channel.id].array.filter!(msg =>
      msg.authorID == this.bot.client.me.id
    ).map!(msg => msg.id).array;

    // Add the command-senders message
    msgs ~= event.msg.id;

    // Delete those messages
    this.client.deleteMessages(event.msg.channel.id, msgs);

    // Send OK message, and delete it + command msg after 3 seconds
    auto msg = event.msg.reply(":recycle: :ok_hand:");
    sleep(3.seconds);
    msg.del();
  }

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
    auto plugin = this.bot.dynamicLoadPlugin(e.args[0], null);
    e.msg.reply(format("Loaded plugin `%s`", plugin.name));
  }

  @Command("list", "list all plugins", "plugin", false, 1)
  void onPluginList(CommandEvent e) {
    e.msg.reply(format("Plugins: `%s`", this.bot.plugins.keys.join(", ")));
  }

  @Command("save", "save all storage", "", false, 1)
  void onSave(CommandEvent e) {
    foreach (plugin; this.bot.plugins.values) {
      plugin.storage.save();
    }
    e.msg.reply("Saved all storage!");
  }

  @Command("roles", "average role counts", "", false, 1)
  void onRoles(CommandEvent e) {
    auto guilds = this.bot.client.state.guilds;

    auto total = 0;
    foreach (guild; guilds.values) {
      total += guild.roles.length;
    }
    e.msg.reply(format(
        "Guilds: %s, Roles: %s, Avg: %s",
        guilds.length,
        total,
        total / guilds.length));
  }
}

extern (C) Plugin create() {
  return new CorePlugin;
}
