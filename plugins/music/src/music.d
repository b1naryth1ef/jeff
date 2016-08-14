module music;

import std.path,
       std.file,
       std.stdio;

import jeff.perms;

import dscord.core,
       dscord.voice.client,
       dscord.voice.youtubedl,
       dscord.util.process;

import dcad.types : DCAFile;

alias VoiceClientMap = ModelMap!(Snowflake, VoiceClient);

class MusicPlugin : Plugin {
  VoiceClientMap voiceClients;

  // Config options
  bool cacheFiles = true;
  string cacheDirectory;

  this() {
    this.voiceClients = new VoiceClientMap;

    auto opts = new PluginOptions;
    opts.useStorage = true;
    opts.useConfig = true;
    super(opts);
  }

  override void load(Bot bot, PluginState state = null) {
    super.load(bot, state);

    if (this.config.has("cache_files")) {
      this.cacheFiles = this.config["cache_files"].get!bool;
    }

    if (this.config.has("cache_directory")) {
      this.cacheDirectory = this.config["cache_dir"].get!string;
    }

    if (!this.cacheDirectory) {
      this.cacheDirectory = this.storageDirectoryPath ~ dirSeparator ~ "cache";
    }

    // Make sure cache folder exists
    if (this.cacheFiles && !exists(this.cacheDirectory)) {
      mkdirRecurse(this.cacheDirectory);
    }
  }

  const string cachePathFor(string hash) {
    return this.cacheDirectory ~ dirSeparator ~ hash ~ ".dca";
  }

  private DCAFile getFromCache(string hash) {
    if (!this.cacheFiles) return null;

    string path = this.cachePathFor(hash);
    if (exists(path)) {
      return new DCAFile(File(path, "r"));
    } else {
      return null;
    }
  }

  private void saveToCache(DCAFile obj, string hash) {
    if (!this.cacheFiles) return;

    string path = this.cachePathFor(hash);
    obj.save(path);
  }

  @Command("join")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("Join the current voice channel")
  void commandJoin(CommandEvent e) {
    auto state = e.msg.guild.voiceStates.pick(s => s.userID == e.msg.author.id);
    if (!state) {
      e.msg.reply("Woah lassy! You need to connect to voice before running that command.");
      return;
    }

    if (this.voiceClients.has(e.msg.guild.id)) {
      if (this.voiceClients[e.msg.guild.id].channel == state.channel) {
        e.msg.reply("Umm... I'm already here bub.");
        return;
      }
      this.voiceClients[e.msg.guild.id].disconnect();
    }

    auto vc = state.channel.joinVoice();
    if (!vc.connect()) {
      e.msg.reply("Huh. Looks like I couldn't connect to voice.");
      return;
    }

    this.voiceClients[e.msg.guild.id] = vc;
    e.msg.reply(":ok_hand: TIME FOR MUSIC.");
  }

  @Command("leave")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("Leave the current voice channel")
  void commandLeave(CommandEvent e) {
    if (this.voiceClients.has(e.msg.guild.id)) {
      this.voiceClients[e.msg.guild.id].disconnect();
      this.voiceClients.remove(e.msg.guild.id);
      e.msg.reply("Bye now.");
    } else {
      e.msg.reply("I'm not even connected to voice 'round these parts.");
    }
  }

  @Command("play")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("Play a URL")
  void commandPlay(CommandEvent e) {
    auto client = this.voiceClients.get(e.msg.guild.id, null);
    if (!client) {
      e.msg.reply("I can't play stuff if I'm not connected to voice.");
      return;
    }

    if (e.args.length < 1) {
      e.msg.reply("Must specify a URL to play.");
      return;
    }

    // TODO: volume control
    VibeJSON info = YoutubeDL.getInfo(e.args[0]);

    if (info == VibeJSON.emptyObject) {
      e.msg.replyf("Wew there... looks like I could find that URL. Try another one?");
      return;
    }

    // Try to grab file from cache, otherwise download directly (and then cache)
    DCAFile file = this.getFromCache(info["id"].get!string);
    if (!file) {
      file = YoutubeDL.download(e.args[0]);
      this.saveToCache(file, info["id"].get!string);
    }

    DCAPlayable result = new DCAPlayable(file);

    // TODO: keep playlist references instead of yolocasting here
    if (client.playing) {
      auto playlist = cast(DCAPlaylist)(client.playable);
      playlist.add(result);
      e.msg.replyf(":ok_hand: I've added song `%s` to the queue, in position %s.", info["title"], playlist.length);
    } else {
      auto playlist = new DCAPlaylist([result]);
      client.play(playlist);
      e.msg.replyf(":ok_hand: Playing your song `%s` now.", info["title"]);
    }
  }

  @Command("pause")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("Pause the playback")
  void commandPause(CommandEvent e) {
    auto client = this.voiceClients.get(e.msg.guild.id, null);
    if (!client) {
      e.msg.reply("Can't pause if I'm not playing anything.");
      return;
    }

    if (client.paused) {
      e.msg.reply("I'm already paused ya silly goose.");
      return;
    }

    client.pause();
  }

  @Command("skip")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("Skip the current song")
  void commandSkip(CommandEvent e) {
    auto client = this.voiceClients.get(e.msg.guild.id, null);
    if (!client) {
      e.msg.reply("Can't pause if I'm not playing anything.");
      return;
    }

    if (!client.playing) {
      e.msg.reply("I'm not playing anything yet bruh.");
      return;
    }

    auto playlist = cast(DCAPlaylist)(client.playable);
    playlist.next();
    e.msg.reply("Skipped...");
  }

  @Command("resume")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("Resume the playback")
  void commandResume(CommandEvent e) {
    auto client = this.voiceClients.get(e.msg.guild.id, null);
    if (!client) {
      e.msg.reply("Can't resume if I'm not playing anything.");
      return;
    }

    if (!client.paused) {
      e.msg.reply("I'm already playing stuff ya silly goose.");
      return;
    }

    client.resume();
  }
}

extern (C) Plugin create() {
  return new MusicPlugin;
}
