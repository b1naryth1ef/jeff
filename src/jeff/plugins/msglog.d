module jeff.plugins.msglog;

import std.stdio,
       std.file,
       std.format,
       std.conv,
       std.regex,
       std.array,
       std.process,
       std.algorithm;

import dscord.core;

struct MsgLogConfig {
  bool console = true;
  bool fs = false;
  bool allowSearch = false;
  string[] searchCommand = ["sift", "-i"];
}

class MsgLogPlugin : Plugin {
  MsgLogConfig  cfg;
  File[Snowflake]  chans;

  StaticRegex!char searchMatch = ctRegex!(r"^[a-zA-Z0-9_\.\* ]*$");

  this(MsgLogConfig cfg) {
    this.cfg = cfg;

    PluginConfig pcfg;
    super(pcfg);

    if (!this.cfg.allowSearch) {
      this.commands["search"].enabled = false;
    }
  }

  @Command("search", "search message logs", "log", false, 1)
  void onSearchCommand(CommandEvent event) {
    auto match = event.contents.matchFirst(this.searchMatch);
    if (!match.length) {
      event.msg.reply("Invalid search string");
      return;
    }

    if (!event.msg.channel) {
      event.msg.reply("Cannot search PM's");
      return;
    }

    // Construct the path and command
    string path = format("logs/%s/%s.txt", event.msg.guild.id, event.msg.channel.id);
    string[] command = this.cfg.searchCommand ~ [`"` ~ event.contents ~ `"`, path]; 

    // Run the process in a shell
    auto process = pipeShell(command.join(" "), Redirect.stdout | Redirect.stderr);

    // Grab all the output in memory
    string[] lines;
    foreach (line; process.stdout.byLine) lines ~= line.idup;
    reverse(lines);

    // Reverse iterate over it, generating lines until we hit the limit
    string[] output;
    int length;
    foreach (line; lines) {
      if ((length + line.length + 1) > 1994) {
        break;
      }

      if (!line.startsWith("[")) {
        continue;
      }

      // Skip formatting these lines lol
      if (line.canFind("```")) {
        continue;
      }

      // If the line contains our UID, skip it as well
      if (line.canFind(this.bot.client.state.me.id.to!string)) {
        continue;
      }

      output ~= line.replace("\\n", "\n");
      length += line.length;
    }


    // If we don't have anything, tell the user
    if (!output.length) {
      event.msg.reply("No results found!");
    }

    // Re-reverse the array
    reverse(output);

    // Otherwise dump our messages out
    event.msg.reply("```" ~ output.join("\n") ~ "```");
  }

  @Listener!MessageCreate()
  void onMessage(MessageCreate event) {
    string line = format("[%s] (%s | %s) #%s %s: %s\n",
      event.message.timestamp,
      event.message.id,
      event.message.channel ? event.message.channel.id : 0,
      event.message.channel ? event.message.channel.name : "PM",
      event.message.author.username,
      event.message.content.replace("\n", "\\n"));

    if (this.cfg.console) {
      write(line);
    }

    if (this.cfg.fs) {
      this.writeToFile(event, line);
    }
  }

  void writeToFile(MessageCreate event, string line) {
    auto msg = event.message;

    if (!(msg.channelID in this.chans)) {
      string path = "logs/";

      if (msg.channel && msg.channel.guild) {
        auto guildID = msg.channel.guild.id.to!string;
        if (!exists(path ~ guildID) || !isDir(path ~ guildID)) {
          mkdir(path ~ guildID);
        }
        path ~= guildID ~ "/";
      }

      path ~= msg.channelID.to!string ~ ".txt";
      this.chans[msg.channelID] = File(path, exists(path) ? "a" : "wa");
    }

    this.chans[msg.channelID].write(line);
    this.chans[msg.channelID].flush();
  }

  override void unload() {
    super.unload();

    foreach (ref f; this.chans.values) {
      f.close();
    }
  }
}
