module jeff.plugins.pickup;

import std.conv;

import dscord.core;

class PickupGame {
  Snowflake  channel;
  ushort     numPlayers;

  ModelMap!(Snowflake, User)  players;

  this(Snowflake chan) {
    this.players = new ModelMap!(Snowflake, User);
    this.channel = chan;
  }

  void end() {}
}

class PickupPlugin : Plugin {
  ModelMap!(Snowflake, PickupGame)  games;

  this() {
    this.games = new ModelMap!(Snowflake, PickupGame);

    PluginConfig cfg;
    super(cfg);
  }

  @Command("start", "start a pug", "pug", false, 1)
  void onStartCommand(CommandEvent event) {
    if (event.args.length < 1) {
      return event.msg.reply("Usage: start <players>");
    }

    if (games.has(event.msg.channelID)) {
      return event.msg.reply("There is already a pug running in this channel!");
    }

    auto game = new PickupGame(event.msg.channelID);
    try {
      this.log.infof("%s", event.args[0]);
      game.numPlayers = to!(ushort)(event.args[0]);
    } catch (Exception e) {
      return event.msg.reply("Invalid number of players!");
    }
    this.games[game.channel] = game;
    event.msg.reply("Alright, its pug time!");
  }

  @Command("join", "join the pug", "pug")
  void onJoinCommand(CommandEvent event) {

  }

  @Command("end", "end a pug", "pug", false, 1)
  void onEndCommand(CommandEvent event) {
    if (!games.has(event.msg.channelID)) {
      event.msg.reply("There is no pug running in this channel!");
      return;
    }

    this.games[event.msg.channelID].end();
    this.games.remove(event.msg.channelID);
    event.msg.reply("OK, pug ended.");
  }
}
