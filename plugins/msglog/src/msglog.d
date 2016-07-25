module msglog;

import std.format,
       std.path,
       std.array;

import d2sqlite3;
import d2sqlite3 : sqlite3Config = config;

import jeff.perms;
import dscord.core;

class MsgLogPlugin : Plugin {
  Database db;

  this() {
    super();

    sqlite3Config(SQLITE_CONFIG_MULTITHREAD);
    this.db = Database(this.storageDirectoryPath ~ dirSeparator ~ "messages.db");
    this.createTable();
  }

  void createTable() {
    this.db.run(`PRAGMA busy_timeout = 500;`);
    this.db.run(`
      CREATE TABLE IF NOT EXISTS messages (
        id UNSIGNED BIG INT PRIMARY KEY,
        channel UNSIGNED BIG INT,
        author UNSIGNED BIG INT,
        guild UNSIGNED BIG INT,
        timestamp DATETIME,
        edited_timestamp DATETIME,
        content TEXT,
        author_name VARCHAR(256),
        channel_name VARCHAR(256),
        guild_name VARCHAR(256),
        deleted BOOLEAN
      )`);

    // TODO: uhh what?
    // this.db.run("CREATE INDEX content_idx ON messsages (content)");
    // this.db.run("CREATE INDEX author_idx ON messages (author)");
  }

  void insertMessage(Message msg) {
    Statement stmt = db.prepare(`
      INSERT INTO messages
        (id, channel, author, guild, timestamp, content,
          author_name, channel_name, guild_name)
      VALUES
        (:id, :channel, :author, :guild, :timestamp, :content,
          :author_name, :channel_name, :guild_name);
    `);

    stmt.inject(
      msg.id,
      msg.channel.id,
      msg.author.id,
      msg.guild ? msg.guild.id : 0,
      msg.timestamp,
      msg.content,
      msg.author.username,
      msg.channel.name,
      msg.guild ? msg.guild.name : "PM");
  }

  void updateMessage(Message msg) {
    Statement stmt = db.prepare(`
      UPDATE messages SET
        content = :content,
        edited_timestamp = :edited_timestamp
      WHERE (
        id = :id
      )
    `);

    stmt.inject(
      msg.content,
      msg.editedTimestamp,
      msg.id
    );
  }

  void markMessageDeleted(Snowflake id) {
    Statement stmt = db.prepare("UPDATE messages SET deleted = 1 WHERE id = :id");
    stmt.inject(id);
  }

  MessageBuffer formatResults(ResultRange results) {
    MessageBuffer msg = new MessageBuffer;

    foreach (Row row; results) {
      if (!msg.appendf("[%s] (%s / %s) %s: %s",
        row["timestamp"],
        row["guild_name"],
        row["channel_name"],
        row["author_name"],
        row["content"])) break;
    }

    return msg;
  }

  @Command("stats")
  @CommandDescription("view message log db stats")
  @CommandGroup("search")
  @CommandLevel(UserGroup.ADMIN)
  void onSearchStats(CommandEvent event) {
    ResultRange rows = db.execute(`
      SELECT guild_name, count(guild) as count
      FROM messages
      GROUP BY guild
    `);

    string content;

    foreach (Row row; rows) {
      content ~= format("%s: %s\n", row["guild_name"].as!string, row["count"].as!int);
    }

    event.msg.replyf("```%s```", content);
  }

  @Command("userinfo")
  @CommandDescription("view message log db user stats")
  @CommandGroup("search")
  @CommandLevel(UserGroup.ADMIN)
  void onSearchUserInfo(CommandEvent event) {
    if (event.msg.mentions.length != 2) {
      event.msg.reply("Must supply user for stats");
      return;
    }

    auto user = event.msg.mentions.values[1];

    auto rows = db.execute(format(`
      SELECT guild_name, count(guild) as count
      FROM messages
      WHERE author=%s
      GROUP BY guild
    `, user.id));

    string content;

    foreach (Row row; rows) {
      content ~= format("%s: %s\n", row["guild_name"].as!string, row["count"].as!int);
    }

    event.msg.replyf("```%s```", content);
  }

  @Command("global")
  @CommandDescription("search message logs globally")
  @CommandGroup("search")
  @CommandLevel(UserGroup.ADMIN)
  void onSearchCommandGlobal(CommandEvent event) {
    Statement query = db.prepare(`
      SELECT
        timestamp, guild_name, channel_name, author_name, content
      FROM messages WHERE
        content LIKE :query AND
        author != :botid;
      ORDER BY timestamp DESC
    `);

    // Bind query
    query.bind(":query", "%" ~ event.cleanedContents ~ "%");
    query.bind(":botid", this.bot.client.me.id);

    // Grab results and format
    ResultRange results = query.execute();
    event.msg.reply(this.formatResults(results));
  }

  @Command("channel")
  @CommandDescription("search message logs in this channel")
  @CommandGroup("search")
  @CommandLevel(UserGroup.MOD)
  void onSearchChannelCommand(CommandEvent event) {
    Statement query = db.prepare(`
      SELECT
        timestamp, guild_name, channel_name, author_name, content
      FROM messages WHERE
        content LIKE :query AND
        channel = :channelid AND
        author != :botid
      ORDER BY timestamp DESC
    `);

    // Bind query
    query.bind(":query", "%" ~ event.cleanedContents ~ "%");
    query.bind(":channelid", event.msg.channel.id);
    query.bind(":botid", this.bot.client.me.id);

    // Grab results and format
    ResultRange results = query.execute();
    event.msg.reply(this.formatResults(results));
  }

  @Command("guild")
  @CommandDescription("search message logs in this guild")
  @CommandGroup("search")
  @CommandLevel(UserGroup.ADMIN)
  void onSearchGuildCommand(CommandEvent event) {
    if (!event.msg.guild) {
      return;
    }

    Statement query = db.prepare(`
      SELECT
        timestamp, guild_name, channel_name, author_name, content
      FROM messages WHERE
        content LIKE :query AND
        guild = :guildid AND
        author != :botid
      ORDER BY timestamp DESC
    `);

    // Bind query
    query.bind(":query", "%" ~ event.cleanedContents ~ "%");
    query.bind(":guildid", event.msg.guild.id);
    query.bind(":botid", this.bot.client.me.id);

    // Grab results and format
    ResultRange results = query.execute();
    event.msg.reply(this.formatResults(results));
  }

  @Listener!MessageCreate()
  void onMessageCreate(MessageCreate event) {
    this.insertMessage(event.message);
  }

  @Listener!MessageUpdate()
  void onMessageUpdate(MessageUpdate event) {
    this.updateMessage(event.message);
  }

  @Listener!MessageDelete()
  void onMessageDelete(MessageDelete event) {
    this.markMessageDeleted(event.id);
  }

  override void unload(Bot bot) {
    this.db.close();
    super.unload(bot);
  }
}

extern (C) Plugin create() {
  return new MsgLogPlugin;
}
