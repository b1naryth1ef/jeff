module music;

import std.path,
       std.file,
       std.stdio,
       std.range,
       std.algorithm,
       std.container.dlist;

import jeff.perms;

import dscord.core,
       dscord.voice.client,
       dscord.voice.youtubedl,
       dscord.util.process;

import dcad.types : DCAFile;

/**
  TODO:
    - Support saving the current song state
    - Better playlist support
    - Volume or live muxing
*/

alias PlaylistItemDList = DList!PlaylistItem;

struct PlaylistItem {
  string id;
  string name;
  string url;

  User addedBy;
  DCAPlayable playable;

  this(VibeJSON song, User author) {
    this.id = song["id"].get!string;
    this.name = song["title"].get!string;
    this.url = song["webpage_url"].get!string;
    this.addedBy = author;
  }
}

class MusicPlaylist : PlaylistProvider {
  Channel channel;
  PlaylistItemDList items;
  PlaylistItem* current;

  this(Channel channel) {
    this.channel = channel;
  }

  void add(PlaylistItem item) {
    this.items.insertBack(item);
  }

  void remove(PlaylistItem item) {
    this.items.linearRemove(find(this.items[], item).take(1));
  }

  void clear() {
    this.items.remove(this.items[]);
  }

  size_t length() {
    return walkLength(this.items[]);
  }

  bool hasNext() {
    return (this.length() > 0);
  }

  Playable getNext() {
    this.current = &this.items.front();
    this.channel.sendMessagef("Now playing: %s", this.current.name);

    this.items.removeFront();
    return this.current.playable;
  }
}

alias VoiceClientMap = ModelMap!(Snowflake, VoiceClient);
alias MusicPlaylistMap = ModelMap!(Snowflake, MusicPlaylist);

class MusicPlugin : Plugin {
  VoiceClientMap voiceClients;
  MusicPlaylistMap playlists;

  // Config options
  bool cacheFiles = true;
  string cacheDirectory;

  this() {
    this.voiceClients = new VoiceClientMap;
    this.playlists = new MusicPlaylistMap;

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

  DCAFile getFromCache(string hash) {
    if (!this.cacheFiles) return null;

    string path = this.cachePathFor(hash);
    if (exists(path)) {
      return new DCAFile(File(path, "r"));
    } else {
      return null;
    }
  }

  void saveToCache(DCAFile obj, string hash) {
    if (!this.cacheFiles) return;

    string path = this.cachePathFor(hash);
    obj.save(path);
  }

  MusicPlaylist getPlaylist(Channel chan, bool create=true) {
    if (!this.playlists.has(chan.guild.id) && create) {
      this.playlists[chan.guild.id] = new MusicPlaylist(chan);
    }
    return this.playlists.get(chan.guild.id, null);
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
      this.voiceClients[e.msg.guild.id].disconnect(false);
      this.voiceClients.remove(e.msg.guild.id);
      e.msg.reply("Bye now.");
    } else {
      e.msg.reply("I'm not even connected to voice 'round these parts.");
    }

    // If we have a playlist, clear it
    auto playlist = this.getPlaylist(e.msg.channel, false);
    playlist.clear();
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

    VibeJSON[] songs = YoutubeDL.getInfo(e.args[0]);

    if (songs.length == 0) {
      e.msg.replyf("Wew there... looks like I couldn't find that URL. Try another one?");
      return;
    } else if (songs.length == 1) {
      e.msg.replyf(":ok_hand: added your song `%s` in position %s.",
        songs[0]["title"], this.addFromInfo(client, e.msg, songs[0]));
      return;
    }

    auto msg = e.msg.replyf(":ok_hand: downloading and adding %s songs...", songs.length);

    MessageBuffer buffer = new MessageBuffer(false);
    bool empty;
    int missed;

    buffer.appendf(":ok_hand: added %s songs:", songs.length);
    foreach (song; songs) {
      empty = buffer.appendf("%s. %s", this.addFromInfo(client, e.msg, song), song["title"]);
      if (!empty) missed++;
    }

    if (!empty && missed) {
      buffer.popBack();
      buffer.appendf("and %s more songs...", missed);
    }

    msg.edit(buffer);
  }

  ulong addFromInfo(VoiceClient client, Message msg, VibeJSON song) {
    auto item = PlaylistItem(song, msg.author);

    // Try to grab file from cache, otherwise download directly (and then cache)
    DCAFile file = this.getFromCache(item.id);
    if (!file) {
      file = YoutubeDL.download(item.url);
      this.saveToCache(file, item.id);
    }
    item.playable = new DCAPlayable(file);

    auto playlist = this.getPlaylist(msg.channel);
    playlist.add(item);

    if (!client.playing) {
      client.play(new Playlist(playlist));
    }

    return playlist.length;
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

    auto playlist = this.getPlaylist(e.msg.channel, false);

    if (!client.playing || !playlist) {
      e.msg.reply("I'm not playing anything yet bruh.");
      return;
    }

    auto playable = cast(Playlist)(client.playable);
    playable.next();
    e.msg.reply("Skipped song...");
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
    e.msg.reply("Music resumed.");
  }

  @Command("queue")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("View the current play queue")
  void commandQueue(CommandEvent e) {
    auto client = this.voiceClients.get(e.msg.guild.id, null);
    if (!client) {
      e.msg.reply("Can't resume if I'm not playing anything.");
      return;
    }

    auto playlist = this.getPlaylist(e.msg.channel, false);
    if (!playlist || !playlist.length) {
      e.msg.reply("Nothing in the queue.");
      return;
    }

    MessageBuffer buffer = new MessageBuffer(false);
    size_t index;

    foreach (item; playlist.items) {
      index++;
      buffer.appendf("%s. %s (added by %s)", index, item.name, item.addedBy.username);
    }

    e.msg.reply(buffer);
  }

  @Command("nowplaying")
  @CommandGroup("music")
  @CommandLevel(UserGroup.GRILL_GAMER)
  @CommandDescription("View the currently playing song")
  void commandNowPlaying(CommandEvent e) {
    auto client = this.voiceClients.get(e.msg.guild.id, null);
    if (!client) {
      e.msg.reply("Can't resume if I'm not playing anything.");
      return;
    }

    auto playlist = this.getPlaylist(e.msg.channel, false);
    if (!playlist || !playlist.current) {
      e.msg.reply("Not playing anything right now");
      return;
    }

    e.msg.replyf("Currently playing: %s (added by %s) [<%s>]",
      playlist.current.name,
      playlist.current.addedBy.username,
      playlist.current.url);
  }
}

extern (C) Plugin create() {
  return new MusicPlugin;
}
