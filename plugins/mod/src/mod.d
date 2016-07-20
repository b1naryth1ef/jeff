module mod;

import std.conv;

import jeff.perms;
import dscord.core;

class ModPlugin : Plugin, UserGroupGetter {
  VibeJSON perms;

  this() {
    auto opts = new PluginOptions;
    opts.useStorage = true;
    super(opts);
  }

  override void load(Bot bot, PluginState state = null) {
    super.load(bot, state);
    this.perms = this.storage.ensureObject("perms");
  }

  UserGroup getGroup(User u) {
    if (!(u.id.to!string in this.perms)) {
      return UserGroup.DEFAULT;
    }

    return this.perms[u.id.to!string].get!UserGroup;
  }

  @Command("set")
  @CommandGroup("group")
  @CommandDescription("set a users group")
  @CommandLevel(UserGroup.ADMIN)
  void setUserGroup(CommandEvent e) {
    if (e.msg.mentions.length != 2) {
      e.msg.reply("Must supply one user and one group!");
      return;
    }

    auto group = getGroupByName(e.args[0]);
    if (group == -1) {
      e.msg.replyf("Invalid group: `%s`", e.args[0]);
      return;
    }

    auto user = e.msg.mentions.values[1];
    this.perms[user.id.to!string] = VibeJSON(group);
    e.msg.replyf("Ok, added %s to group %s", user.username, e.args[0]);
  }

  @Command("get")
  @CommandGroup("group")
  @CommandDescription("get a users group")
  @CommandLevel(UserGroup.MOD)
  void getUserGroup(CommandEvent e) {
    if (e.msg.mentions.length != 2) {
      e.msg.reply("Must supply one user to lookup!");
      return;
    }

    auto user = e.msg.mentions.values[1];

    if (!(user.id.to!string in this.perms)) {
      e.msg.replyf("No group set for user %s", user.username);
      return;
    }

    UserGroup group = this.perms[user.id.to!string].get!UserGroup;
    e.msg.replyf("User %s is in group %s", user.username, group);
  }

  @Command("kick")
  @CommandDescription("kick a user")
  @CommandLevel(UserGroup.MOD)
  void kickUser(CommandEvent e) {
    if (e.msg.mentions.length != 2) {
      e.msg.reply("Must supply user to kick!");
      return;
    }

    auto user = e.msg.mentions.values[1];
    e.msg.guild.kick(user);
    e.msg.replyf("Kicked user %s", user.username);
  }
}

extern (C) Plugin create() {
  return new ModPlugin;
}
