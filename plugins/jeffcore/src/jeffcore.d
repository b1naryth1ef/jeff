module jeffcore;

import std.format,
       std.conv,
       std.array,
       std.algorithm.iteration;

import dscord.core,
       dscord.util.emitter,
       dscord.util.queue,
       dscord.util.counter;

import jeff.perms;
import vibe.core.core : sleep;

// Extra struct used for storing a light amount of message data.
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
  // Number of messages to keep per channel (in the heap)
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

    // If the queue is empty just skip this message
    if (this.msgHistory[event.channelID].empty) {
      return;
    }

    // If the message ID isn't even in the heap, skip it
    if (event.id < this.msgHistory[event.channelID].peakFront().id) {
      return;
    }

    auto msgs = this.msgHistory[event.channelID].array.filter!(msg => msg.id != event.id);
    this.msgHistory[event.channelID].clear();
    assert(this.msgHistory[event.channelID].push(msgs.array));
  }

  @Listener!GuildDelete()
  void onGuildDelete(GuildDelete event) {
    auto guild = this.client.state.guilds.get(event.guildID, null);

    if (!guild) {
      return;
    }

    foreach (ref channel; guild.channels.keys) {
      if ((channel in this.msgHistory) !is null) {
        this.msgHistory.remove(channel);
      }
    }
  }

  @Listener!ChannelDelete()
  void onChannelDelete(ChannelDelete event) {
    if ((event.channel.id in this.msgHistory) !is null) {
      this.msgHistory.remove(event.channel.id);
    }
  }

  @Command("ping")
  void onPing(CommandEvent event) {
    event.msg.reply("pong");
  }

  @Command("jumbo")
  @CommandDescription("make an emoji jumbo sized")
  void onJumbo(CommandEvent event) {
    auto custom = event.msg.customEmojiByID();

    if (custom.length) {
      event.msg.chain.maybe.del().replyf("https://cdn.discordapp.com/emojis/%s.png", custom[0]);
    }
  }

  @Command("heapstats")
  @CommandDescription("get stats about the message heap")
  @CommandLevel(UserGroup.ADMIN)
  void onHeapStats(CommandEvent event) {
    string msg = "";
    msg ~= format("Total Channels: %s\n", this.msgHistory.length);
    msg ~= format("Total Messages: %s", this.msgHistory.values.map!((m) => m.size).reduce!((x, y) => x + y));
    event.msg.replyf("```%s```", msg);
  }

  @Command("clean")
  @CommandDescription("clean chat by deleting previously sent messages")
  @CommandLevel(UserGroup.MOD)
  void onClean(CommandEvent event) {
    if ((event.msg.channel.id in this.msgHistory) is null || this.msgHistory[event.msg.channel.id].empty) {
      event.msg.reply("No previously sent messages in this channel!").after(3.seconds).del();
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
    event.msg.reply(":recycle: :ok_hand:").after(3.seconds).del();
  }

  @Command("counts")
  @CommandGroup("event")
  @CommandDescription("view event counters")
  @CommandLevel(UserGroup.ADMIN)
  void onEventStats(CommandEvent event) {
    ushort numEvents = 5;
    if (event.args.length >= 1) {
      numEvents = to!(ushort)(event.args[0]);
    }

    string[] parts;
    foreach (e; this.counter.mostCommon(numEvents)) {
      parts ~= format("%s: %s", e, this.counter.storage[e]);
    }

    event.msg.replyf("```%s```", parts.join("\n"));
  }

  @Command("show")
  @CommandGroup("event")
  @CommandDescription("view stats on a specific event")
  @CommandLevel(UserGroup.ADMIN)
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

    event.msg.replyf("I've seen %s event a total of `%s` times!", eventName, this.counter.storage[eventName]);
  }

  Plugin pluginCommand(CommandEvent e, string action) {
    if (e.args.length != 1) {
      e.msg.replyf("Must provide a plugin name to %s", action);
      throw new EmitterStop;
    }

    if ((e.args[0] in this.bot.plugins) is null) {
      e.msg.replyf("Unknown plugin `%s`", e.args[0]);
      throw new EmitterStop;
    }

    return this.bot.plugins[e.args[0]];
  }

  @Command("reload")
  @CommandGroup("plugin")
  @CommandDescription("reload a plugin")
  @CommandLevel(UserGroup.ADMIN)
  void onPluginReload(CommandEvent e) {
    auto plugin = this.pluginCommand(e, "reload");

    // Defer the reload to avoid being within the function stack of the DLL, or
    //  smashing our stack while we're in another event handler.
    e.event.defer({
      plugin = this.bot.dynamicReloadPlugin(plugin);
      e.msg.replyf("Reloaded plugin `%s`", plugin.name);
    });
  }

  @Command("unload")
  @CommandGroup("plugin")
  @CommandDescription("unload a plugin")
  @CommandLevel(UserGroup.ADMIN)
  void onPluginUnload(CommandEvent e) {
    auto plugin = this.pluginCommand(e, "unload");

    // Similar to above, defer unloading the plugin
    e.event.defer({
      // Send the message first or 'plugin' will nullref
      e.msg.replyf("Unloaded plugin `%s`", plugin.name);
      this.bot.unloadPlugin(plugin);
    });
  }

  @Command("load")
  @CommandGroup("plugin")
  @CommandDescription("load a plugin by path")
  @CommandLevel(UserGroup.ADMIN)
  void onPluginLoad(CommandEvent e) {
    if (e.args.length != 1) {
      e.msg.reply("Must provide a DLL path to load");
      return;
    }

    // Note: this is super unsafe, should always be owner-only
    auto plugin = this.bot.dynamicLoadPlugin(e.args[0], null);
    e.msg.replyf("Loaded plugin `%s`", plugin.name);
  }

  @Command("list")
  @CommandGroup("plugin")
  @CommandDescription("list all plugins")
  @CommandLevel(UserGroup.ADMIN)
  void onPluginList(CommandEvent e) {
    e.msg.replyf("Plugins: `%s`", this.bot.plugins.keys.join(", "));
  }

  @Command("save")
  @CommandDescription("save all storage")
  @CommandLevel(UserGroup.ADMIN)
  void onSave(CommandEvent e) {
    foreach (plugin; this.bot.plugins.values) {
      if (plugin.storage) {
        plugin.storage.save();
      }
    }
    e.msg.reply("Saved all storage!");
  }
}

extern (C) Plugin create() {
  return new CorePlugin;
}
