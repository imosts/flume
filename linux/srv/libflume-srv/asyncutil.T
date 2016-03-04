// -*-c++-*-
/* $Id: pslave.h 1682 2006-04-26 19:17:22Z max $ */

#include "asyncutil.h"
#include <signal.h>
#include "flume_srv_const.h"
#include "flume_cpp.h"
#include "litetime.h"

void
init_clock ()
{
  str e = safegetenv (FLUME_CLCK_EV);
  sfs_clock_t typ;
  if (e) { 
    if (strncasecmp (e.cstr (), "timer", e.len ()) == 0) {
      typ = SFS_CLOCK_TIMER;
    } else {
      typ = SFS_CLOCK_MMAP;
    }
  } else {
    typ = SFS_CLOCK_GETTIME;
  }
  sfs_set_clock (typ, e);

}

tamed void
debug_attach (cbv cb, str s)
{
  tvars {
    str v;
  }
  if (!s) s = flume_dbg_attach_env_var;
  v = getenv (s);
  if (v && v.len () > 0 && v != "0") {
    warn << "[pid=" << getpid () << "]: waiting for SIGCONT\n";
    twait { sigcb (SIGCONT, mkevent ()); }
    warn << "[pid=" << getpid () << "]: got signal; continuing...\n";
    sigcb (SIGCONT, NULL);
  }
  cb->trigger ();
}

void safevtrig (cbv::ptr *c)
{
  if (*c) {
    cbv tmp (*c);
    *c = NULL;
    tmp->trigger ();
  }
}

void
add_flag (vec<str> *v, const char *f)
{
  v->push_back (f);
}

void
add_opt (vec<str> *v, const char *o, const str &s)
{
  v->push_back (o);
  v->push_back (s);
}

int
flmsockopt (int i)
{
  int optval = 1;
  int rc = setsockopt (i, SOL_SOCKET,
		       SO_SNDLOWAT, (const void *)&optval, sizeof (optval));
  if (rc < 0) {
    warn ("setsockopt failed: %m\n");
  }
  return rc;
}
