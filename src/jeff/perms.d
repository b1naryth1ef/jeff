module jeff.perms;

import dscord.core;

interface UserGroupGetter {
  int getGroup(User);
}

/// Class that handles shimming Jeff permissions inbetween plugin commands
class CommandShim {

}
