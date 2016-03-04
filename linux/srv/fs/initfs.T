
// -*-c++-*-
/* $Id: pslave.h 1682 2006-04-26 19:17:22Z max $ */

#include "flume.h"
#include "fsutil.h"
#include "parseopt.h"
#include "flume_srv_const.h"
#include <sys/types.h>
#include <errno.h>
#include "flume_idd_prot.h"

static void
usage ()
{
  warnx << "usage: " << progname << " [-G -I<idd>] <root>\n";
  exit (0);
}


tamed static void
init_file (fs::ea_mgr_t *eam, const str &fn, cbi cb)
{
  tvars {
    frozen_labelset_t l;
    flume_status_t st;
    int rc;
  }
  memset ((char *)&l, 0, sizeof (l));
  
  twait { eam->setlabelset (fn, l, mkevent (st)); }
  if (st != FLUME_OK) {
    warn << fn << ": set label failed.\n";
    rc = -1;
  } else {
    rc = 0;
  }
  cb->trigger (rc);
}

tamed static void
main2 (int argc, char **argv)
{
  tvars {
    int ch;
    int tmp;
    bool ghetto;
    str idd_str;
    fs::cfg_t cfg;
    bool ok;
    int rc (0);
    int i;
    str s;
  }

  while ((ch = getopt (argc, argv, "GI:")) != -1) {
    switch (ch) {
    case 'I':
      idd_str = optarg;
      break;
    case 'G':
      ghetto = true;
      break;
    default:
      usage ();
      break;
    }
  }

  if (ghetto && !idd_str)
    usage ();

  twait { cfg.simple_init (ghetto, idd_str, mkevent (ok)); }
  if (!ok) {
    warn << "Could configure the FS!\n";
    usage ();
  }
  
  argv += optind;
  argc -= optind;

  if (argc == 0) 
    usage ();

  for (i = 0; i < argc; i++) {
    s = argv[i]; // keep 's' around to prevent mystery coredumps
    warn << "set empty EAs on file: " << s << "\n";
    twait { init_file (cfg.ea_mgr (), s, mkevent (tmp)); }
    if (tmp < 0) {
      warn << argv[i] << ": init extended attributes failed.\n";
      rc = -1;
    }
  }

  exit (rc);
}

int 
main (int argc, char *argv[])
{
  setprogname (argv[0]);
  main2 (argc, argv);
  amain ();
}
