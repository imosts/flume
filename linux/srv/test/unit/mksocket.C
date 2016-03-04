
#include "async.h"
#include "flume_srv_const.h"
#include "fsutil.h"

//
// a little script that proves you can set extended attributes on unix
// domain sockets.
//

static void
usage ()
{
  warnx << "usage: " << progname << " <socket>\n";
}

static void 
foo (flume_status_t st)
{
}


int
main (int argc, char *argv[])
{
  fs::real_ea_mgr_t ream;
  if (argc != 2) {
    usage ();
  }
  int rc = unixsocket (argv[1]);
  if (rc < 0) {
    warn ("Unixsocket(%s) failed: %m\n", argv[1]);
    exit (1);
  }
  frozen_labelset_t ls;
  ls.S = 0x1234;
  ream.setlabelset (rc, ls, wrap (foo));
  amain ();
}
