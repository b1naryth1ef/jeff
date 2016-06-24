module pickup;

import std.conv;

import dscord.core,
       dscord.util.emitter;

class PickupGame {
  Snowflake  channel;
  ushort     numPlayers;

  ModelMap!(Snowflake, User)  players;

  this(Snowflake chan) {
    this.players = new ModelMap!(Snowflake, User);
    this.channel = chan;
  }

  void addPlayer(User u) {
    this.players[u.id] = u;
    if (this.players.length == this.numPlayers) {
      this.start();
    }
  }

  void removePlayer(User u) {}

  void start() {}
  void end() {}
}

class PickupPlugin : Plugin {
  ModelMap!(Snowflake, PickupGame)  games;

  this() {
    this.games = new ModelMap!(Snowflake, PickupGame);

    PluginConfig cfg;
    super(cfg);
  }

  PickupGame expectGame(Message msg) {
    if (!this.games.has(msg.channelID)) {
      msg.reply("There is no pug running in this channel");
      throw new EmitterStop();
    }

    return this.games.get(msg.channelID);
  }

  @Command("start", "start a pug", "pug", false, 1)
  void onStartCommand(CommandEvent event) {
    if (event.args.length < 1) {
      return event.msg.reply("Usage: start <players>");
    }

    if (games.has(event.msg.channelID)) {
      return event.msg.reply("There is already a pug running in this channel");
    }

    auto game = new PickupGame(event.msg.channelID);

    try {
      game.numPlayers = to!(ushort)(event.args[0]);
    } catch (Exception e) {
      return event.msg.reply("Invalid number of players");
    }

    this.games[game.channel] = game;
    event.msg.reply("Alright, its pug time");
  }

  @Command("join", "join the pug", "pug")
  void onJoinCommand(CommandEvent event) {
    auto game = this.expectGame(event.msg);

    if (game.players.has(event.msg.author.id)) {
      return event.msg.reply("You are already in the pug");
    }

    game.addPlayer(event.msg.author);
    event.msg.reply("You've joined the pug");
  }

  @Command("leave", "leave the pug", "pug")
  void onLeaveCommand(CommandEvent event) {
    auto game = this.expectGame(event.msg);

    if (!game.players.has(event.msg.author.id)) {
      return event.msg.reply("You are not a member of the current pug");
    }

    game.removePlayer(event.msg.author);
    event.msg.reply("You've left the pug");
  }

  @Command("end", "end a pug", "pug", false, 1)
  void onEndCommand(CommandEvent event) {
    auto game = this.expectGame(event.msg);
    this.games[event.msg.channelID].end();
    this.games.remove(event.msg.channelID);
    event.msg.reply("OK, pug ended");
  }
}

extern (C) Plugin create() {
  return new PickupPlugin;
}
