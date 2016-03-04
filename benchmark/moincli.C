#include "moincli.h"

vec<moinuser_t> moin_cli::musers;

moin_cli::moin_cli (int dummy) : tmoin_cli (dummy) { }

base_cli*
moin_cli::clone () {
  moin_cli *c = New moin_cli ();
  c->clone_base (this);
  return c;
}

str
moin_cli::make_cookie () {
  int user_idx;
  strbuf cookie;

  if (!userlist)
    return str("");

  if (sequential_users) {
    user_idx = counter % musers.size ();
  } else {
    user_idx = random () % musers.size ();
  }

  cookie.fmt ("Cookie: MOIN_ID=%s\r\n", musers[user_idx].moinid);
  return str(cookie);
}

void
moin_cli::read_userlist (str path)
{
  int rc, i=1;
  FILE *f;
  moinuser_t u;

  if (!(f = fopen (path.cstr(), "r")))
    fatal << "could not open userlist " << path << "\n";

  while ((rc = fscanf (f, "%s %s %s\n", u.uname, u.pw, u.moinid)) > 0) {
    if (rc != 3) 
      fatal ("malformed entry in userlist, line %d, matched %d\n", i, rc);

    if (noisy) fprintf (ERR, "uname %s moinid %s\n", u.uname, u.moinid);
    musers.push_back (u);
    i++;
  }
  if (noisy) fprintf (ERR, "read %d login pairs from userlist\n", musers.size());
  nusers = musers.size ();
  fclose (f);
}

str
moin_cli::cmd_name () {
  return "moincli";
}
