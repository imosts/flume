
#include "flume_idd_prot.h"
#include "flume_srv_const.h"
#include "unixutil.h"
#include "parseopt.h"
#include "idd.h"

static void
usage ()
{
  warnx << "usage: " << progname << " [-f <configfile>]\n";
  exit (1);
}

int
main (int argc, char *argv[])
{
  setprogname (argv[0]);
  int ch;
  str configfile;
  idd::idd_t *idd_obj;

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
    configfile = flume_etcfile_required (idd::config_filename_base);

  if (!configfile) {
    warn << "No configfile specified or found.\n";
    usage ();
  }

  idd_obj = New idd::idd_t ();

  idd_obj->launch (configfile);
  amain ();
}
