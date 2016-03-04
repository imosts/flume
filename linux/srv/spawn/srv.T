
// -*-c++-*-
#include "async.h"
#include "crypt.h"
#include "arpc.h"

#include "spawn.h"
#include "flume_spawn_prot.h"
#include "tame_autocb.h"
#include "flume_cpp.h"
#include "flume_prot.h"
#include "tame_io.h"
#include <stdio.h>
#include <sys/prctl.h>

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

extern char **environ;


namespace flmspwn { 

  handle_t g_flmpid;
  bool _in_child;

  //-----------------------------------------------------------------------

  handle_t getflmpid () { return g_flmpid; }

  //-----------------------------------------------------------------------

  spawner_t::spawner_t (const cfg_t &o)
    : jailable_t (o._chroot_dir), 
      _cfg (o), 
      _in_child (false) {}

  //-----------------------------------------------------------------------

  spawner_t::~spawner_t () {}

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::init (cbb cb)
  {
    tvars {
      bool ret (false);
    }

    if (!isunixsocket (0)) {
      warn << "File descriptor 0 is not a Unix Socket, as expected.\n";
      warn << "Check that this program was launched by flumerm.\n";
    } else if (!chroot ()) {
      warn ("chroot operation failed: %m\n");
      ret = false; 
    } else if (getuid() == 0 && !_cfg.setuid ()) {
      warn ("setuid/setgid operation failed\n");
      ret = false;
    } else {
      bool keep_stderr = false;
      if (FLUMEDBG(FLUME_DEBUG_FDS|FLUME_DEBUG_SPAWN)) {
	keep_stderr = true;
      }
      _open_fds.insert (0, false, true, "stdin");
      _open_fds.insert (1, false, false, "stdout");
      _open_fds.insert (2, keep_stderr, false, "stderr");
      _open_fds.insert (3, false, true, "sfs-internal FD");
      _open_fds.insert (4, false, true, "sfs-internal FD");
      ret = true;
      _in_child = false;
    }

    cb->trigger (ret);
  }
  //-----------------------------------------------------------------------
  
  void
  spawner_t::dispatch (svccb *sbp)
  {
    assert (!_in_child);
    if (!sbp) {
      shutdown ();
      return;
    }
    switch (sbp->proc ()) {
    case FLUME_SPAWN_NULL:
      sbp->replyref (0);
      break;
    case FLUME_SPAWN_SPAWN:
      handle_spawn (sbp);
      break;
    default:
      sbp->reject (PROC_UNAVAIL);
      break;
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::do_spawn (const spawn_i_arg_t *arg, spawn_i_res_t *res,
		       int ctlfd, cbv cb)
  {
    tvars {
      int fds[2];
      flume_status_t st (FLUME_OK);
      pid_t pid;
      x_handle_t c_flmpid (arg->flmpid);
      int status;
      clnt_stat err;
      spawn_i_exit_t earg;
      flume_status_t eres;
    }

    res->set_status (FLUME_OK);

    // the child needs to keep this open, even after a close_all, so therefore
    // pass 'true' as a second arg. note that the parent will explicitly
    // close the ctlfd, so the 'true' flag doesn't apply
    _open_fds.insert (ctlfd, true, false, 
	                  strbuf ("[%" PRIx64 "] ctlfd", c_flmpid));

    if (pipe (fds) < 0) {
      st = FLUME_EFD;
    } else {
      _open_fds.insert (fds[0], false, true, 
			strbuf ("[%" PRIx64 "] parentfd", c_flmpid));
      _open_fds.insert (fds[1], true, false,
			strbuf ("[%" PRIx64 "] childfd", c_flmpid));

      pid = fork ();
      if (pid < 0) {
        _open_fds.close (ctlfd);
        st = FLUME_EFORK;
      
      } else if (pid == 0) {
	_in_child = true;
	g_flmpid = c_flmpid;

	_open_fds.close (fds[0]);
        _open_fds.close (0);

	_x = NULL;
	_srv = NULL;
	_cli = NULL;

	do_spawn_child (arg, ctlfd, fds[1]);

	// note, do_spawn_child might return intermediately as
	// as result of tame calls. the best thing to do then is
	// just to return out of this function.
	return;

      } else {
	if (_in_child) 
	  return;

	_open_fds.close (fds[1]);
	_open_fds.close (ctlfd);

	twait { do_spawn_parent (pid, fds[0], res , mkevent ()); }
	if (_in_child)
	  return;

      }
    }
    if (res->status == FLUME_OK && st != FLUME_OK) {
      res->set_status (st);
    }
    cb->trigger ();

    // Now wait for a childcb; don't touch arg or res though, since
    // they probably disappeared....
    twait { chldcb (pid, mkevent (status)); }
    if (_in_child)
      return;

    earg.flmpid = c_flmpid;
    earg.pid = pid;
    earg.status = status;

    twait { _cli->call (FLUME_SPAWN_EXIT, &earg, &eres, mkevent (err)); }
    if (_in_child)
      return;

    if (err) {
      warn << "Error in sending exit(2) message to RM: " << err << "\n";
    } else if (eres != FLUME_OK) {
      warn ("[%d]: Error in Exit RPC: %d\n", pid, int (eres));
    }

  }

  //-----------------------------------------------------------------------
  
  tamed void
  spawner_t::open (const str &fn, file_res_t *res, cbi cb)
  {
    tvars {
      file_arg_t arg;
      clnt_stat stat;
      int rc (-1);
    }

    arg.c_args.path = fn;
    arg.c_args.mode = 0;
    arg.c_args.flags = O_RDONLY;
    
    twait { _cli->call (OPEN_FILE, &arg, res, mkevent (stat)); }
    if (stat) {
      res->set_status (FLUME_ERPC);
      *res->error = int (stat);
    } else if (res->status == FLUME_PATH_OK) {
      rc = _x->recvfd ();
      FLUMEDBG4(PROCESS, CHATTER, "Open succeeded: %s -> %d\n", fn.cstr(), rc);
    }

    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------
  
  tamed void
  spawner_t::claim_fd (x_handle_t h, cbi cb, int n)
  {
    tvars { 
      int rc, fd;
      claim_res_t claimres;
      clnt_stat err;
      register_fd_arg_t arg;
      flume_status_t res;
      claim_arg_t claimarg;
    }
    rc = -1;

    claimarg.token = h;
    {
      strbuf b ("claimed fd %d", n);
      claimarg.desc = b;
    }

    twait { _cli->call (FLUME_CLAIM_FD, &claimarg, &claimres, mkevent (err)); }

    if (err || claimres.status != FLUME_OK) {
      rc = -1;
    } else if ((fd = _x->recvfd ()) < 0) {
      rc = -1;
    } else {
      arg.rm_side = claimres.ok->opaque_h;
      arg.proc_side = fd;
      twait { _cli->call (FLUME_REGISTER_FD, &arg, &res, mkevent (err)); }
      if (err) {
        /* no-op */
      } else {
        rc = fd;
      }
    }
    FLUMEDBG4(SPAWN, CHATTER, "New FD claimed from RM: %d\n", rc);
    cb->trigger (rc);
  }
  
  //-----------------------------------------------------------------------

  struct exec_fd_t {
    enum { PROG = 0, LINKER = 1, INTERP = 2, COUNT = 3 };

    void open (spawner_t *open, evv_t ev, CLOSURE);
    
    bool activate (fdtab_t *tab);

    void close (fdtab_t *tab) 
    { 
      if (_fd >= 0) {
	tab->close (_fd); 
      }
      clear ();
    }

    void clear () 
    { 
      _path = NULL;
      _fpath = NULL;
      _fd = -1; 
    }

    exec_fd_t () : _fd (-1) {}
    str _path;
    str _fpath;
    int _fd;
    file_res_t _res;
    str _which;
  };

  //-----------------------------------------------------------------------

  tamed void
  exec_fd_t::open (spawner_t *spwn, evv_t ev)
  {
    twait { spwn->open (_path, &_res, mkevent (_fd)); }
    if (_res.status == FLUME_PATH_OK) {
      _fpath = *_res.path;
    }
    ev->trigger ();
  }

  //-----------------------------------------------------------------------

  bool
  exec_fd_t::activate (fdtab_t *tab)
  {
    bool ret = false;

    if (_fd > 0) {
      
      // Insert each fd into the FD tab;
      tab->insert (_fd, true, false, 
		   strbuf ("[%" PRIx64 "] %sfd", getflmpid ().value (), 
			   _which.cstr()));

      // Enable close-on-exec!
      fcntl (_fd, F_SETFD, 1);
      prctl (FLUME_PRCTL_PUTFD, _fd, 0, 0, 0);
      ret = true;

    }
    return ret;
  }

  //-----------------------------------------------------------------------

  static bool
  get_interp (int fd, str *interp, str *arg)
  {
#define INTERPSZ 0x100
    bool ret = false;

    // hardcode the arcane restriction that only 1 arg is needed.
    static rxx x ("#!\\s*(\\S+)(\\s+(\\S*)\\s*)?");

    char buf[INTERPSZ+1];
    memset (buf, 0, sizeof (buf));

    int rc = read (fd, buf, INTERPSZ);
    if (rc > 0 && x.match (buf)) {
      *interp = x[1];
      if (x[3] && x[3].len ())
	*arg = x[3];
      ret = true;
    }

    return ret;
#undef INTERPSZ
  }

  //-----------------------------------------------------------------------

  /*
   * Perform a series of label changes, as specified by the given
   * arguments.  Keep going until we're all done, or until one of
   * them failed.  If one of them failed, communicate the
   * failure back to the parent process.  The parent will know if
   * the process 'disappeared' or not, and will respond to the 
   * application accordingly.
   */
  tamed void
  spawner_t::do_label_changes (const spawn_i_arg_t &arg,
			       file_res_t *res, 
			       evv_t ev)
  {
    tvars {
      size_t i;
      bool ok (true);
    }
    for (i = 0; ok && i < arg.label_changes.size (); i++) {

      twait { do_label_change (arg.label_changes[i], res, mkevent (ok)); }
    }
    ev->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::do_label_change (const x_label_change_t &ls, 
			      file_res_t *res,
			      evb_t ev)
  {
    tvars {
      clnt_stat err;
      set_label_arg_t slarg;
      flume_res_t slres;
      bool ok (false);
    }

    slarg.which.type = ls.which;
    slarg.which.specifiers.set_scope (LABEL_SCOPE_PROCESS);
    slarg.new_label = ls.label;

    twait { _cli->call (SET_LABEL, &slarg, &slres, mkevent (err)); }

    if (err) {
      res->set_status (FLUME_ERPC);
      *res->error = int (FLUME_ERPC);
    } else if (slres.status == FLUME_OK) {
      ok = true;
    } else {
      res2res (slres, res);
    } 

    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::do_spawn_child (const spawn_i_arg_t *arg, int ctlfd, int parentfd)
  {
    tvars {
      exec_fd_t efds[exec_fd_t::COUNT];
      
      file_res_t *sendres (NULL);
      file_res_t frtmp (FLUME_OK);

      str iarg;
      str tmp;
      strbuf b;
      clnt_stat stat;
      int pid;
      int rc;
      unsigned int i;
      flume_status_t flmstat (FLUME_OK);
      env_t env (arg->c_args.env);
      vec<str> argv;
      int badfd (-1);

      ptr<axprt_stream> x;
      ptr<aclnt> cli;
      clnt_stat e;

      str progpath;
    }

    efds[exec_fd_t::PROG]._which = "prog";
    efds[exec_fd_t::LINKER]._which = "link";
    efds[exec_fd_t::INTERP]._which = "interp";

    // Hack for this function: we're using the file_res_t somewhat
    // inappropriately to track error codes, and to pass a status
    // update from the child to the parent.

    // copy the ctlfd to 3 or greater!
    _open_fds.hold_places (N_STD_FDS, ctlfd);
    _x = axprt_unix::alloc (ctlfd);
    _cli = aclnt::alloc (_x, flume_prog_1);

    // child needs to call getpid to find its pid; do this before
    // calling enable systrace!!!
    pid = getpid ();

    // Need to enable systrace before the parent replies to 
    // its SPAWN RPC, so do it now and get it over with.
    if ((arg->opts & SPAWN_CONFINED)) {

      // Third argument '1' is that we're entering exec mode, in which
      // it's OK to open directories...
      int rc = prctl (FLUME_PRCTL_ENABLE, FLUME_CONFINE_ENFORCED, 1, 0, 0);
      if (rc < 0) {
	warn ("Error from prctl confinement enable: %m\n"); 
	flmstat = FLUME_ERPC;
	frtmp.set_status (flmstat);
	*frtmp.error = int (stat);
      }
    }

    if (flmstat == FLUME_OK) {
      twait {
	do_label_changes (*arg, &frtmp, mkevent ());
      }
      if (frtmp.status != FLUME_OK) {
	flmstat = frtmp.status;
	sendres = &frtmp;
      }
    }

    // Next get needed privileges and handle setuid, and also
    // make the appropriate argv after we've read in the setuid
    // changes.
    if (flmstat == FLUME_OK && (arg->opts & SPAWN_SETUID)) {
      twait { 
	do_setuid (*arg, &efds[exec_fd_t::PROG]._path, 
		   &argv, &frtmp, mkevent ()); 
      }
      if (frtmp.status != FLUME_OK) {
	flmstat = frtmp.status;
	sendres = &frtmp;
      }
    } else {
      efds[exec_fd_t::PROG]._path = arg->c_args.cmd;
      vec2vec (arg->c_args.argv, &argv);
    }

    if (flmstat == FLUME_OK) {

      // XXX bug -- should read this from the ELF file headers
      // instead.
      efds[exec_fd_t::LINKER]._path = _cfg._linker;
      
      twait {
	for (i = 0 ; i < exec_fd_t::INTERP; i++) {
	  efds[i].open (this, mkevent ());
	}
      }

      for (i = 0; i < exec_fd_t::INTERP; i++)
	if (efds[i]._res.status != FLUME_PATH_OK)
	  badfd = i;

      if (badfd < 0) {

	i = exec_fd_t::INTERP;
	if (get_interp (efds[exec_fd_t::PROG]._fd, &efds[i]._path, &iarg)) {
	  twait { efds[i].open (this, mkevent ()); }
	  if (efds[i]._res.status != FLUME_PATH_OK) {
	    badfd = i;
	  } else {

	    size_t slots = 1;

	    // we got a good interpreter (and argument) so now we 
	    // can go ahead and prepend it to the argument vector
	    if (iarg && iarg.len ())
	      slots ++;

	    // Unfortunately, can't push_front, so we'll fake it.
	    for (size_t k = 0; k < slots; k++) {
	      argv.push_back (NULL);
	    }
	    for (size_t k = 0; k < argv.size () - slots; k++) {
	      argv[k+slots] = argv[i];
	    }
	    argv[0] = efds[i]._fpath;
	    if (iarg && iarg.len ())
	      argv[1] = iarg;

	    // close the program, we don't need it anymore
	    efds[exec_fd_t::PROG].close (&_open_fds);

	    // the program now becomes the interpreter
	    efds[exec_fd_t::PROG] = efds[i];

	    // the interpreter is zero'd out, but not closed!
	    efds[i].clear ();
	  }
	}
      }

      if (badfd < 0) {

	for (i = 0; i < exec_fd_t::COUNT; i++) {
	  
	  // put each FD into the internal accounting tab, and register
	  // each open FD with the kernel, so that the process is
	  // allowed to access it during the exec call.
	  efds[i].activate (&_open_fds);
	}

      } else { 
	sendres = &efds[badfd]._res;
	warn ("Open failure in do_spawn_child "
	      "(prog=%d,linker=%d,interp=%d)\n", 
	      efds[exec_fd_t::PROG]._fd, 
	      efds[exec_fd_t::LINKER]._fd, 
	      efds[exec_fd_t::INTERP]._fd);

	flmstat = sendres->status;
      }
    }

    if (flmstat == FLUME_OK) {
      
      // close stdin, stdout and stderr; don't do this in debug mode.
      // should leave open: CTLFD and PARENTFD
      _open_fds.close_all ();

      if (arg->claim_fds) {

	rc = 0;
	for (i=0; rc >= 0 && i<arg->claim_fds->size (); i++) {
	  twait { claim_fd (arg->claim_fds->at (i), mkevent (rc), i); }
	  if (rc < 0) {
	    warn ("Failed to fetch FD for handle: 0x%" PRIx64 "\n", 
		  arg->claim_fds->at (i));
	    flmstat = FLUME_ENOENT;
	  } 
	}
      }
    }
    
    // send the result of the pre-exec operations to the parent in a
    // 'file_res_t', which is somewhat of a hack.  If our status is
    // not OK, then we have to make sure we report the error to 
    // the parent process.
    if (!sendres) {
      sendres = &frtmp;
      sendres->set_status (flmstat);
    }

    tmp = xdr2str (*sendres);
    assert (tmp);

    b << tmp;

    if (b.tosuio ()->output (parentfd) < 0) {
      warn ("Short write write in do_child: %m\n");
      exit (-1);
    }

    if (flmstat != FLUME_OK) {
      warn ("Failed after fork, before exec: status=%d\n", int (flmstat));
      exit (-1);
    }

    // need to close this separately since we asked the FDtab to keep
    // it open.
    _open_fds.close (parentfd);
      
    env.set (FLUME_SFD_EV, strbuf () << ctlfd);
    env.set (FLUME_PRCID_EV, strbuf ("0x%" PRIx64, arg->flmpid));
    env.set (FLUME_CONFINED_EV, FLUME_YES);

    // Enable to debug spawn....
    /* env.set (FLUME_DBG_EV, "0xfffff"); */
    
    // For now, just make sure the ctlfd is working for the child
    // (it appears not to be after a fork).
    if (false) {

      x = axprt_stream::alloc (ctlfd);
      cli = aclnt::alloc (x, flume_prog_1);
      
      twait { cli->call (FLUME_NULL, NULL, NULL, mkevent (e)); }
      if (e) {
	warn << "Test RPC failed: " << e << "\n";
      } else {
	warn << "Test RPC success!!\n";
      }
      
      x = NULL;
      cli = NULL;
    }

    // Otherwise, C library will get confused....
    make_sync (ctlfd);

    if ((arg->opts & SPAWN_CONFINED)) {
      str t = getenv (LD_LIBRARY_PATH);
      strbuf b;
      b << _cfg._ld_library_path;
      if (t) 
	b << ":" << t;
      str s = b;

      //XXX debug
      //warn << "Setenv (" << LD_LIBRARY_PATH << "=" << s << ")\n";
      env.set (LD_LIBRARY_PATH, s);
    }

    // disable close-on-exec
    fcntl (ctlfd, F_SETFD, 0);

    
    // this prog path might actually have been translated, so update
    // argv[0] accordingly
    progpath = efds[exec_fd_t::PROG]._fpath;
    argv[0] = progpath;

    do_execve (progpath, argv, env.to_argv ());
    panic ("do_execve should not return!\n");
  }

  //-----------------------------------------------------------------------

  void
  spawner_t::do_execve (const str &cmd, const vec<str> &argv, ptr<argv_t> env)
  {
    argv_t a (argv);
    const char *prog = cmd;

    int rc = execve (prog, a.dat (), env->dat ());
    if (rc < 0) {
      warn ("Execution failed on '%s': %m\n", prog);
      exit (rc);
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::do_spawn_parent (pid_t pid, int tmpfd, spawn_i_res_t *res, cbv cb)
  {
    tvars {
      strbuf b;
      int rc;
      file_res_t fr;
    }

    make_async (tmpfd);
    do {
      twait { tame::waitread (tmpfd, mkevent ()); }
      if (_in_child)
        return;
      rc = b.tosuio ()->input (tmpfd);
    } while (rc > 0 || (rc < 0 && errno == EAGAIN));

    if (_in_child)
      return;

    // make sure we remove it from the table, so that children don't
    // try to close it in the future...
    _open_fds.close (tmpfd);

    if (b.tosuio()->resid() == 0) {
      warn ("spawner pid %d, Child %d did not send return code "
	    "in do_spawn_parent\n", getpid(), pid);
      res->set_status (FLUME_ESPAWN);
    } else if (rc != 0) {
      warn ("Communication failure in do_spawn_parent: %m\n");
      res->set_status (FLUME_ESPAWN);
    } else {
      str tmp = b;
      if (!str2xdr (fr, tmp)) {
	warn ("XDR failure in do_spawn_parent\n");
	res->set_status (FLUME_ESPAWN);
      } else {
	res->set_status (fr.status);
	if (fr.status == FLUME_OK) {
	  res->ok->pid = pid;
	} else if (fr.status == FLUME_EPERM) {
	  *res->eperm = *fr.eperm;
	}
      }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::handle_spawn (svccb *sbp)
  {
    tvars {
      spawn_i_arg_t *arg (sbp->Xtmpl getarg<spawn_i_arg_t> ());
      spawn_i_res_t res (FLUME_OK);
      int _ctl_fd;
    }
    
    if ((_ctl_fd = _x->recvfd ()) < 0) {
      res.set_status (FLUME_EFD);
    } else {
      twait { do_spawn (arg, &res, _ctl_fd, mkevent ()); }
      if (_in_child)
	return;
    }
    sbp->replyref (res);
  }


  //-----------------------------------------------------------------------

  void
  spawner_t::shutdown ()
  {
    warn << "Caught EOF from rm; shutting down...\n";
    delete this;
    exit (0);
  }
  
  //-----------------------------------------------------------------------
  
  void
  spawner_t::run ()
  {
    _x = axprt_unix::alloc (0);
    _cli = aclnt::alloc (_x, flume_spawn_prog_1);
    _srv = asrv_delayed_eof::alloc (_x, flume_spawn_prog_1, 
				    wrap (this, &spawner_t::dispatch));
  }

  //-----------------------------------------------------------------------

  void
  env_t::insert (const str &v)
  {
    static rxx x ("([^=]+)(=(.*))?");
    if (x.match (v)) {
      set (x[1], x[3]);
    } else {
      FLUMEDBG4(PROCESS, ERROR, "Unparsable env variable: %s", v.cstr ());
    }
  }

  //-----------------------------------------------------------------------

  void
  env_t::set (const str &k, const str &v)
  {
    _map.insert (k, v);
  }

  //-----------------------------------------------------------------------
  
  ptr<argv_t>
  env_t::to_argv () const
  {
    qhash_const_iterator_t<str,str> it (_map);
    const str *k;
    str v;
    vec<str> vc;
    while ((k = it.next (&v))) {
      strbuf b;
      b << *k << "=";
      if (v)
	b << v;
      vc.push_back (b);
      v = NULL;
    }
    return New refcounted<argv_t> (vc);
  }
  
  //-----------------------------------------------------------------------
};
