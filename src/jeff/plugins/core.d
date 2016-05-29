module jeff.plugins.core;

import std.format;

import dscord.core;

class CorePlugin : Plugin {
  this() {
    PluginConfig cfg;
    super(cfg);
  }

  @Command("about")
  void onAboutCommand(CommandEvent event) {
    event.msg.reply("hi, im jeff by b1nzy :^)");
  }
}
