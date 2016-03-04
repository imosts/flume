
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
  warnx << "usage: " << progname 
	<< " [-I <iddhost:iddport>] [-cG] "
	<< "[-s<lab>] [-o<lab>] [-i<lab>] <files>\n";
  exit (-1);
}

static bool
check (handle_t h, const char *which)
{
  if (h.value () != 0 && !h.is_identifier ()) {
    warn << "Provided '" << which << "' label is not valid\n";
    return false;
  }
  return true;
}

tamed static void
main2 (int argc, char **argv)
{
  tvars {
    int ch;
    handle_t s, o, i;
    bool set_s (false), set_o (false), set_i (false);
    bool clear (false);
    bool debug (false);
    int rc (0);
    int j;
    fs::cfg_t cfg;
    str file;
    int fd;
    frozen_labelset_t ls;
    bool ghetto (false);
    flume_status_t st;
    int this_rc;
    str idd_str;
    bool ok;
  }

  while ((ch = getopt (argc, argv, "GI:dcs:o:i:")) != -1) {
    switch (ch) {
    case 'G':
      ghetto = true;
      break;
    case 'I':
      idd_str = optarg;
      break;
    case 'd':
      debug = true;
      break;
    case 'c':
      clear = true;
      set_s = set_o = set_i = true;
      break;
    case 's':
      if (!s.from_str (optarg))
	usage ();
      set_s = true;
      break;
    case 'o':
      if (!o.from_str (optarg))
	usage ();
      set_o = true;
      break;
    case 'i':
      if (!i.from_str (optarg))
	usage ();
      set_i = true;
      break;
    default:
      usage ();
      break;
    }
  }
  
  twait { cfg.simple_init (ghetto, idd_str, mkevent (ok)); }
  if (!ok) {
    warn << "Could not configure this FS\n";
    usage ();
  }

  if (!(check (s, "s") && check (i, "i") && check (o, "o")))
    usage ();

  argc -= optind;
  argv += optind;

  for (j = 0; j < argc; j++) {

    this_rc = 0;
    file = argv[j];
    fd = open (file.cstr(), O_RDONLY);
    if (fd < 0) {
      warn << "Could not open file: " << file << "\n";
      this_rc = -1;
    } else {
      memset ((void *)&ls, 0, sizeof (ls));
      if (!clear) {
	twait { cfg.ea_mgr ()->getlabelset (fd, &ls, mkevent (st)); }
	if (st != FLUME_OK) {
	  warn ("Cannot get labelset on file '%s': %m\n", file.cstr ());
	  this_rc = -1;
	}
      }
    }

    if (this_rc == 0) {
      if (set_s) {
	ls.S = s.value ();
      }
      if (set_o) {
	ls.O = o.value ();
      }
      if (set_i) {
	ls.I = i.value ();
      }
      twait { cfg.ea_mgr ()->setlabelset (fd, ls, mkevent (st)); }
      if (st != FLUME_OK) {
	warn ("Cannot set labelset on file '%s': %m\n", file.cstr ());
	this_rc = -1;
      } else if (debug) {
	warn ("setfile '%s' succeeded\n", file.cstr ());
      }
    }
    if (fd >= 0) 
      close (fd);
    if (this_rc < 0)
      rc = this_rc;

  }

  exit (rc);
  
}

int
main (int argc, char *argv[])
{
  setprogname (argv[0]);
  main2 (argc, argv);
  amain () ;

}
