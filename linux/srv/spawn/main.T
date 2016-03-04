// -*-c++-*-

#include "spawn.h"
#include "parseopt.h"
#include "spawnutil.h"
#include "asyncutil.h"
#include "sfs_select.h"

tamed static void
main_T (int argc, char **argv)
{
  tvars {
    flmspwn::spawner_t *srv;
    int rc (-1);
    flmspwn::cfg_t cfg;
    bool ok;
  }

  // Get some random bytes, so we initalize the PRNG before the chroot
  arandom();
  arandom();
  
  sfs_core::set_zombie_collect (true);

  setprogname (argv[0]);
  set_debug_flags ();

  twait { debug_attach (mkevent ()); }

  if (!cfg.parseopts (argc, argv, ""))
    exit (rc);

  // initalize internal data for running the thing.
  cfg.init ();

  warn << "Spawner starting up [pid=" << getpid () << "]: " 
       << cfg.to_str () << "\n";

  srv = New flmspwn::spawner_t (cfg);

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
