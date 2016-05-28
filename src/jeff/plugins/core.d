module jeff.plugins.core;

import dscord.core;

class CorePlugin : Plugin {
  this() {
    PluginConfig cfg;
    super(cfg);
  }

  @Command("about")
  void onAboutCommand(MessageCreate event) {
    event.message.reply("hi, im jeff by b1nzy :^)");
  }
}
