
#include "async.h"
#include "crypt.h"
#include "rm.h"
#include "unixutil.h"
#include "flume_srv_const.h"
#include "parseopt.h"
#include "flume_ev_debug.h"

static void
usage ()
{
  warnx << "usage: " << progname << " [-f <configfile>]\n";
  exit (1);
}

rm::rm_t *rm_obj;

int
main (int argc, char *argv[])
{
  // Open and listen on /dev/systrace
  setprogname (argv[0]);
  int ch;
  str configfile;

  set_debug_flags ();
  init_clock ();
  random_init ();

  while ((ch = getopt (argc, argv, "f:")) != -1) {
    switch (ch) {
    case 'f':
      configfile = optarg;
      break;
    default:
      usage ();
      break;
    }
  }

  if (configfile && !can_read (configfile)) {
    warn << "Cannot access config file for reading: " << configfile << "\n";
    exit (1);
  }

  if (!configfile) 
    configfile = flume_etcfile_required (rm::config_filename_base);
  if (!configfile) {
    warn << "No configfile specified or found.\n";
    usage ();
  }
  rm_obj = New rm::rm_t ();
  rm_obj->launch (configfile);
  amain ();
}
