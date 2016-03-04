
// -*-c++-*-

#include "async.h"
#include "arpc.h"
#include "flume_prot.h"
#include "rm.h"
#include "unixutil.h"
#include "parseopt.h"
#include "flume_idd_prot.h"
#include "iddutil.h"
#include "flume_cfg.h"

#if SFSLITE_AT_VERSION(1,2,1,0)
# include "sfs_select.h"
# define CAN_BUSYWAIT 1
#endif

extern char ** environ;
extern int optind;

namespace rm {

  //
  //=======================================================================
  // Config file parsing
  //
  bool
  rm_t::got_generic_exec (vec<str> &s, str loc, bool *errp, 
			  ptr<argv_t> *ep)
  {
    str cmd, err, prog;
    vec<str> env;
    
    strip_comments (&s);
    
    assert (s.size () > 0);
    
    cmd = s.pop_front ();
    
    while (s.size () && strchr (s[0].cstr (), '=')) 
      env.push_back (s.pop_front ());
    
    if (s.size ()) {
      *ep = New refcounted<argv_t> (env, environ);
    }
    
    if (s.size () < 1) 
      goto usage;
    
    prog = s[0];
    if (!is_safe (prog)) {
      warn << loc << ": specified program " << prog
	   << ") contains unsafe substrings\n";
      goto fail;
    }
    
    prog = flume_exec (prog);
    err = can_exec (prog);
    if (err) {
      warn << loc << ": cannot open program '" << prog 
	   << "': " << err << "\n";
      *errp = true;
    } else {
      s[0] = prog;
      return true;
    }
    
  usage:
    warn << loc << ": usage: " << cmd << " [ENV] <path-to-bin> <args>\n";
  fail:
    *errp = true;
    return false;
  }

  //-----------------------------------------------------------------------

  str
  rm_t::flume_exec (const str &s) const
  {
    return (s[0] == '/' ? s : str (strbuf (_topdir) << "/" << s));
  }
  
  //-----------------------------------------------------------------------

  void
  rm_t::got_spawner (vec<str> v, str loc, bool *errp)
  {
    flmspwn::cfg_t cfg;
    if (got_generic_exec (v, loc, errp, &cfg._env)) {
      strbuf b;
      b << loc << ": " ;

      argv_t argv (v);
      optind = 1;
      if (cfg.parseopts (argv.size (), argv, b)) {

	bool rc = true;

	if (!cfg._user) cfg._user = default_spawn_user ();
	if (!cfg._group)cfg._group = default_spawn_group ();

	if (!cfg._user) {
	  warn << loc << ": cannot get user to run spawner as\n";
	  rc = false;
	}

	if (!cfg._group) {
	  warn << loc << ": cannot get group to run spawner as\n";
	  rc = false;
	}

	if (rc)
	  _spawner = New refcounted<spawner_t> (cfg);
	else
	  *errp = true;
      } else {
	warn << b << "usage: Spawner [ENV] <bin> [<opts>]"
	     << " [<chroot-jail>]\n";
	*errp = true;
      }
    }

  }

  //-----------------------------------------------------------------------

  void
  rm_t::got_fs (vec<str> v, str loc, bool *errp)
  {
    bool rc = true;
    fs::cfg_t fscfg;
    ptr<fs_t> fs;

    if (!got_generic_exec (v, loc, errp, &fscfg._env)) {
      rc = false;
    } else {
      strbuf b;
      b << loc << ": ";
      loc = b;

      argv_t argv (v);
      optind = 1;
      if (fscfg.parseopts (argv.size (), argv, loc)) {

	if (!fscfg._user) fscfg._user = default_fs_user ();
	if (!fscfg._group) fscfg._group = default_fs_group ();

	if (!fscfg._user) {
	  warn << loc << ": cannot get user to run filesystem as\n";
	  rc = false;
	}
	
	if (!fscfg._group) {
	  warn << loc << ": cannot get group to run filesystem as\n";
	  rc = false;
	}

	if (fscfg._optmz) 
	  fs = New refcounted<fs_optmz_t> (fscfg);
	else
	  fs = New refcounted<fs_t> (fscfg);

        if (fscfg._ghetto_eas && getuid() != 0) {
          warn << loc << "RM must run as root when using ghetto EAs\n";
          rc = false;
        }

	add_fs (fs);
	
      } else {
	rc = false;
      }
    }

    if (!rc) { 
      warn << loc << "usage: FileServer [ENV] <bin> "
	"[<opts>] [<dir>] [<mount-point>]\n";
      *errp = true;
    }
  }

  //-----------------------------------------------------------------------

  void
  rm_t::got_idd (vec<str> v, str loc, bool *errp)
  {
    str cmd = v[0];
    str errstr;
    if (v.size () <= 1 || !_idd_cfg.from_argv (v, &errstr)) {
      warn << loc << ": usage: " << _idd_cfg.usage () << "\n";
      if (errstr) {
	warn << errstr;
      }
      *errp = true;
    }
  }

  //-----------------------------------------------------------------------

  void
  rm_t::alloc_handle_mgr ()
  {
    global_idd_init (idd (), _handle_seed);
  }

  //-----------------------------------------------------------------------

  void
  rm_t::got_setuid_h (vec<str> v, str loc, bool *errp)
  {
    if (v.size () != 2) {
      warn << loc << ": usage: SetuidHandle <handle>\n";
      *errp = true;
    } else {
      ptr<handle_t> h = New refcounted<handle_t> ();
      if (!h->from_str (v[1])) {
	warn << loc << ": cannot decode handle: " << v[1] << "\n";
	*errp = true;
      } else {
	_setuid_h = h;
      }
    }
  }

  //-----------------------------------------------------------------------

  bool
  rm_t::parse_file(const str &f)
  {
    conftab ct;

    ct.add ("FileServer", wrap (this, &rm_t::got_fs))
      .add ("SocketFile", &_socket_file)
      .add ("Spawner", wrap (this, &rm_t::got_spawner))
      .add ("SystraceFile", &_systrace_file)
      .add ("TopDir", &_topdir)
      .add ("DefaultFsUser", &_def_fs_username)
      .add ("DefaultFsGroup", &_def_fs_groupname)
      .add ("DefaultSpawnUser", &_def_spawn_username)
      .add ("DefaultSpawnGroup", &_def_spawn_groupname)
      .add ("Seed", &_handle_seed)
      .add ("SocketFileMode", &_socket_file_mode, 0, 0777)
      .add ("IDD", wrap (this, &rm_t::got_idd))
      .add ("DebugFlags", &_debug_flags, 0, 0xffffff)
      .add ("SetuidHandle", wrap (this, &rm_t::got_setuid_h))
      .add ("include", wrap (static_cast<config_parser_t *> (this), 
			     &config_parser_t::include))
      .add ("Greedy", &_greedy)
      .ignore ("LinkerName");

    return ct.run (f);
  }

  //-----------------------------------------------------------------------
  
  bool
  rm_t::post_config (const str &fn)
  {
    if (!_setuid_h)
      _setuid_h = New refcounted<handle_t> (handle_t::def_setuid_h ());
    return true;
  }

  //-----------------------------------------------------------------------

  ptr<flume_usr_t>
  rm_t::default_fs_user ()
  { 
    return default_user (&_def_fs_u, _def_fs_username, "FS user");
  }

  //-----------------------------------------------------------------------

  ptr<flume_usr_t>
  rm_t::default_spawn_user ()
  {
    return default_user (&_def_spawn_u, _def_spawn_username, "Spawn user");
  }

  //-----------------------------------------------------------------------

  ptr<flume_usr_t>
  rm_t::default_user (ptr<flume_usr_t> *u, const str &def, const char *what)
  {
    if (!*u || (*u)->getname () != def) {
      *u = New refcounted<flume_usr_t> (def);
      if (!**u) {
	warn << "Cannot find " << what << ": " << def << "\n";
	*u = NULL;
      }
    }
    return *u;
  }

  //-----------------------------------------------------------------------

  ptr<flume_grp_t>
  rm_t::default_fs_group ()
  { 
    return default_group (&_def_fs_g, _def_fs_groupname, "FS group");
  }

  //-----------------------------------------------------------------------

  ptr<flume_grp_t>
  rm_t::default_spawn_group ()
  {
    return default_group (&_def_spawn_g, _def_spawn_groupname, "Spawn group");
  }

  //-----------------------------------------------------------------------

  ptr<flume_grp_t>
  rm_t::default_group (ptr<flume_grp_t> *g, const str &def, const char *what)
  {
    if (!*g || (*g)->getname () != def) {
      *g = New refcounted<flume_grp_t> (def);
      if (!**g) {
	warn << "Cannot find " << what << ": " << def << "\n";
	*g = NULL;
      }
    }
    return *g;
  }

  //
  // End config file parsing
  //=======================================================================
  //

  //
  //=======================================================================
  // Object startup and initialization
  //

  rm_t::rm_t () :
    config_parser_t (),
    _topdir (topdir),
    _socket_file (socket_file),
    _systrace_file (systrace_file),
    _def_fs_username (fs::default_username),
    _def_fs_groupname (fs::default_groupname),
    _def_spawn_username (flmspwn::default_username),
    _def_spawn_groupname (flmspwn::default_groupname),
    _strfd (-1), 
    _srvfd (-1),
    _socket_open (false),
    _idd (NULL),
    _socket_file_mode (socket_file_mode),
    _debug_flags (0),
    _greedy (false)
  {}

  //-----------------------------------------------------------------------

  rm_t::~rm_t ()
  {
    if (_socket_open) {
      unlink (_socket_file.cstr ()); 
    }
  }

  //-----------------------------------------------------------------------

  void
  rm_t::caught_signal (int which)
  {
    warn << "Caught signal: " << which << "; shutting down.\n";
    exit (0);
  }

  //-----------------------------------------------------------------------

  void
  rm_t::init_signals ()
  {
    sigcb (SIGTERM, wrap (this, &rm_t::caught_signal, SIGTERM));
    sigcb (SIGINT,  wrap (this, &rm_t::caught_signal, SIGINT));
  }

  //-----------------------------------------------------------------------

  tamed void
  rm_t::launch (str cf)
  {
    tvars {
      bool ok;
    }
  
    if (!run_configs (cf)) {
      warn << "Bad configuration file.\n";
      exit (1);
    }

    init_signals ();

    warn << progname << " starting up; [pid=" << getpid () << "]\n";

    twait { start_idd (mkevent (ok)); }
    if (!ok) { 
      warn << "Failed to start IDD: exiting\n";
      exit (1);
    }

    alloc_handle_mgr ();

    twait { start_spawner (mkevent (ok)); }
    if (!ok) {
      warn << "Failed to start spawner: exiting\n";
      exit (1);
    }

    twait { start_fileservers ( mkevent (ok) ); }
    if (!ok) {
      warn << "Failed to start file servers; exiting.\n";
      exit (1);
    }

    twait { start_client ( mkevent (ok) ); }
    if (!ok) {
      warn << "Failed to start Unix domain client; exiting.\n";
      exit (1);
    }

    if (can_fake_confinement ()) {
      flumedbg_warn (SECURITY, "UNSAFE! Processes can toggle safe flag");
    }

    if (_greedy) {
#ifdef CAN_BUSYWAIT
      flumedbg_warn (CHATTER, "Greedy CPU mode enabled!\n");
      sfs_core::set_busywait (true);
#else 
      flumedbg_warn (ERROR, "Cannot enable busywait with "
		     "older sfslite version. Need version %s; got version %s",
		     "1.2.1+", SFSLITE_PATCHLEVEL_STR);
#endif /* CAN_BUSYWAIT */
      
    }

  }
    
  //-----------------------------------------------------------------------

  tamed void
  rm_t::start_systrace (cbb cb)
  {
    tvars {
      bool ret (true);
    }
    if ((_strfd = systrace_open()) < 0) {
      warn << "systrace open failed\n";
      ret = false;
    } else {
      fdcb (_strfd, selread, wrap (this, &rm_t::systrace_read));
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------
  /*
   * In this case, the "client" is the loop that sits on the socket
   * between jailed processes and the rm, listening to requests
   * initiated by the jailed processes and doing the appropriate
   * actions.  
   */
  tamed void
  rm_t::start_client (cbb cb)
  {
    tvars {
      bool ret (true);
    }

    if (!ready_socket (_socket_file)) {
      ret = false;
    } else if ((_srvfd = unixsocket (_socket_file)) < 0) {
      warn << "Error creating client socket (UNIX)" << 
	strerror (errno) << "\n";
      ret = false;
    } else {
      _socket_open = true;
      if (_socket_file_mode > 0) 
	if (chmod (_socket_file.cstr (), _socket_file_mode) < 0) {
	  warn ("fchmod failed on file %s: %m\n", _socket_file.cstr ());
	}
      if (listen (_srvfd, 100) < 0) { 
	warn ("Error from listen: %m\n");
	close (_srvfd);
	ret = false;
      } else {
	warn << "flumerm listening on socket " << _socket_file << "\n";
	fdcb (_srvfd, selread, wrap (this, &rm_t::socket_accept_client));
      }
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  rm_t::start_fileservers (cbb cb)
  {
    tvars {
      size_t i;
      rcset_t<bool> rc (true);
    }

    rc.setsize (_fs.size ());

    twait {
      for (i = 0; i < _fs.size (); i++) {
	// Insert all fileservers into the mountpoint tree
	_tree.insert (_fs[i]->mountpoint (), _fs[i]);
	_fs[i]->set_handle_seed (_handle_seed);
	_fs[i]->launch (_idd, mkevent (rc[i]));
      }
    }
    cb->trigger (rc.project ());
  }

  //-----------------------------------------------------------------------

  tamed void
  rm_t::start_idd (cbb cb)
  {
    tvars {
      bool ret (false);
      flume_status_t st;
    }
    twait { _idd_cfg.alloc_and_start (&_idd, mkevent (ret)); }
    if (ret) {
      twait { idd ()->insert (*_setuid_h, "setuid handle", mkevent (st)); }
      if (st != FLUME_OK && st != FLUME_EEXIST) {
	warn << "Failed to register setuid handle with IDD\n";
	ret = false;
      }
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  rm_t::start_spawner (cbb cb)
  {
    tvars {
      bool ret (true);
    }
    if (!_spawner) {
      ret = false;
    } else {
      twait { _spawner->launch (mkevent (ret), this); }
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::launch (cbb cb, rm_t *rm)
  {
    tvars {
      vec<str> argv;
      bool ret (true);
      int sig;
    }

    if (!_cfg.to_argv (&argv)) {
      ret = false;
    } else {

      char *const *e = NULL;
      if (_cfg._env) e = *_cfg._env;
      _x = axprt_unix_aspawnv (argv[0], argv, flume_ps, NULL, e);
      if (!_x) {
	ret = false;
      } else {
	
	// Linux doesn't like this
	//flmsockopt (_x->getfd ());

	_cli = aclnt::alloc (_x, flume_spawn_prog_1);
	_srv = asrv_delayed_eof::alloc (_x, flume_spawn_prog_1,
					wrap (rm, &rm_t::dispatch_spawn));
	_pid = axprt_unix_spawn_pid;
      }
    }
    cb->trigger (ret);


    twait { chldcb (_pid, mkevent (sig)); }
    rm->clear_spawner ();
    warn << dbg_name () << " exiting with status=" << sig << "\n";

    _x = NULL;
    _cli = NULL;
    _srv = NULL;
    _pid = -1;
  }

  //-----------------------------------------------------------------------

  tamed void
  fs_optmz_t::launch_T (const idd::server_handle_t *idd, cbb cb)
  {
    tvars {
      bool b;
    }
    twait { fs_t::launch (idd, mkevent (b)); }
    cb->trigger (b);
  }

  //-----------------------------------------------------------------------

  tamed void
  fs_t::launch_T (const idd::server_handle_t *idd, cbb cb)
  {
    tvars {
      vec<str> argv;
      bool ret (true);
      size_t i;
      bool ok;
      char *const *e (NULL);
    }

    _cfg.set_idd (idd);

    if (!_cfg.to_argv (&argv)) {
      ret = false;
    } else {
      
      if (_cfg._env) e = *_cfg._env;
      
      _cli.setsize (_cfg._n_proc);
      
      for (i = 0; i < _cli.size () && ret; i++) {
	_cli[i].init (this, i);
	twait { _cli[i].launch (argv, e, mkevent (ok)); }
	if (!ok) {
	  ret = false;
	}
      }
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  fs_t::cli_t::launch (const vec<str> &argv, char *const *env, evb_t ev)
  {
    tvars {
      bool ret (true);
    }

    _x = axprt_unix_aspawnv (argv[0], argv, flume_ps, NULL, env);

    if (!_x) {
      ret = false; 
    } else {
      _cli = aclnt::alloc (_x, flume_fs_prog_1);
      _pid = axprt_unix_spawn_pid;
      chldcb (_pid, wrap (this, &fs_t::cli_t::caught_sig));
    }
    ev->trigger (ret);
  }
    
  //
  //=======================================================================
  //

};
