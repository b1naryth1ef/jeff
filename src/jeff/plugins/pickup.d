module jeff.plugins.pickup;

import dscord.core;

class PickupGame {
  Snowflake  channel;

  string game = "";
  ushort players = 10;

  this(Snowflake chan) {
    this.channel = chan;
  }

  void end() {}
}

class PickupPlugin : Plugin {
  ModelMap!(Snowflake, PickupGame)  games;

  this() {
    this.games = new ModelMap!(Snowflake, PickupGame);

    PluginConfig cfg;
    cfg.cmdPrefixes = ["pug", "pu"];
    super(cfg);
  }

  @Command("start")
  void onStartCommand(MessageCreate event) {
    if (games.has(event.message.channelID)) {
      event.message.reply("There is already a pug running in this channel!");
      return;
    }

    auto game = new PickupGame(event.message.channelID);
    this.games[game.channel] = game;
    event.message.reply("Alright, its pug time!");
  }

  @Command("end")
  void onEndCommand(MessageCreate event) {
    if (!games.has(event.message.channelID)) {
      event.message.reply("There is no pug running in this channel!");
      return;
    }

    this.games[event.message.channelID].end();
    this.games.remove(event.message.channelID);
    event.message.reply("OK, pug ended.");
  }
}
