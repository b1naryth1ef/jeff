module jeff.perms;

import dscord.core;

interface UserGroupGetter {
  int getGroup(User);
}
