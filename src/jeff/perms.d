module jeff.perms;

import dscord.core;

enum UserGroup {
  IDIOT = -100,
  DEFAULT = 0,
  REGULAR = 1,
  GRILL_GAMER = 3,
  MOD = 2,
  ADMIN = 100,
}

int getGroupByName(string name) {
  switch (name) {
    case "idiot":
      return UserGroup.IDIOT;
    case "default":
      return UserGroup.DEFAULT;
    case "regular":
      return UserGroup.REGULAR;
    case "grillgamer":
      return UserGroup.GRILL_GAMER;
    case "mod":
      return UserGroup.MOD;
    case "admin":
      return UserGroup.ADMIN;
    default:
      return -1;
  }
}

interface UserGroupGetter {
  UserGroup getGroup(User);
}

