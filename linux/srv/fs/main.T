
// -*-c++-*-

#include "fs.h"
#include "parseopt.h"
#include "fsutil.h"
#include "asyncutil.h"

tamed static void
main_T (int argc, char **argv)
{
  tvars {
    fs::simple_srv_t *srv;
    int rc (-1);
    fs::cfg_t cfg;
    bool ok;
  }
  setprogname (argv[0]);
  set_debug_flags ();
  init_clock ();

  twait { debug_attach (mkevent ()); }

  if (!cfg.parseopts (argc, argv, ""))
    exit (rc);

  // initalize internal data for running the thing.
  cfg.init ();

  warn << "FS starting up [pid=" << getpid () << "]: " 
       << cfg.to_str () << "\n";

  srv = New fs::simple_srv_t (cfg);

  twait { srv->init (mkevent (ok)); }
  if (!ok)
    exit (rc);

  srv->run ();
}

int 
main (int argc, char *argv[])
{
  main_T (argc, argv);
  amain ();
}
