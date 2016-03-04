// -*-c++-*-

#include "async.h"
#include "crypt.h"
#include "arpc.h"
#include "flume_prot.h"
#include "rm.h"
#include "systrace_policy.h"
#include "flume_idd_prot.h"

#ifdef __linux__
#include <sys/prctl.h>
#endif

#ifdef HAVE_DEV_SYSTRACE_H
# include <dev/systrace.h>
#endif /* HAVE_DEV_SYSTRACE_H */

namespace rm {

  void
  proc_t::handle_random_str (svccb *sbp)
  {
#define LIM 0x800
    u_int *arg = sbp->Xtmpl getarg<u_int> ();
    random_str_t res;
    char buf[LIM];
    u_int n = min<u_int> (*arg, LIM);
    rnd.getbytes (buf, n);
    str s = armor32 (buf, n);
    res = s;
    sbp->replyref (res);
#undef LIM
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_kill (svccb *sbp) 
  {
    flume_status_t st = FLUME_OK;
    kill_arg_t *ka = sbp->Xtmpl getarg<kill_arg_t> ();
    proc_t *p = rm ()->_procs_by_flmpid[ka->flmpid];
    if (p && (*labelset () <= *p->labelset ())) {
      kill (p->pid (), ka->sig);
    }
    // XXX for now, don't report any sort of error, which I think
    // should be OK.
    sbp->replyref (st);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_apply_filter (svccb *sbp)
  {
    tvars {
      apply_filter_arg_t *arg (sbp->Xtmpl getarg<apply_filter_arg_t> ());
      file_arg_t farg;
      file_res_t res;
      ptr<eval::ctx_t> ctx (eval::ctx_t::alloc ());
      flume_status_t st;
      ptr<filter_t> filt;
    }

    farg.c_args.path = arg->path;
    farg.c_args.flags = 0;

    twait { read_filter (&farg, &res, mkevent ()); }
    if (res.status == FLUME_FILTER_OK) {
      filt = New refcounted<filter_t> (res.filter->filter);
      twait {
	hmgr ()->check_filter (*filt, res.filter->req_privs, 
			       mkevent (st), ctx);
      }
      if (st == FLUME_EPERM) {
	ctx->to_xdr (&res);
      } else if (st == FLUME_OK && 
		 !_filter_set->push_back (*filt, arg->which)) {
	st = FLUME_ELABEL;
      }
      if (st != FLUME_OK) {
	res.set_status (st);
      } else {
	// DON'T Leak the login data!!!
	res.filter->req_privs.clear ();
      }
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::read_filter (const file_arg_t *arg, file_res_t *res, cbv cb)
  {

    twait {
      _rm->fsop (FLUME_FS_READ_FILTER, _cwd, arg, labelset (), 
		 FS_OP_GETFILTER, res, mkevent (), _filter_set);
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_getcwd (svccb *sbp)
  {
    tvars {
      fs_path_t res;
    }
    res = _cwd ? _cwd : "/";
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  // Create a socket into the RM.
  tamed void
  proc_t::handle_socket (svccb *sbp, ptr<axprt_unix> x)
  {
    tvars {
      file_res_t res;
      flume_status_t stat;
      int fd;
      handle_t h;
    }

    twait {create_dangling_socket (&h, mkevent (stat, fd)); }
    if (stat == FLUME_OK && fd >= 0) {
      res.set_status (FLUME_FDPASS_OK_OPAQUE);
      *res.opaque_h = h;
      make_sync (fd);
      x->sendfd (fd);
    } else {
      res.set_status (stat);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_connect (svccb *sbp, ptr<axprt_unix> x)
  {
    tvars {
      connect_arg_t *arg (sbp->Xtmpl getarg<connect_arg_t> ());
      file_arg_t farg;
      int f (FS_OP_FDPASS);
      flume_status_t stat (FLUME_ERR);
      file_res_t res;
      bool ok;
    }

    farg.c_args = arg->c_args;
    farg.O_label = arg->O_label;
    //makefarg.xls = NULL;
    farg.ep = arg->ep;

    twait {
      _rm->fsop (FLUME_FS_UNIXCONNECT, _cwd, &farg,
                 labelset ()->clone (),
                 f, &res, mkevent (), _filter_set);
    }

    if (res.status == FLUME_FDPASS_OK) {
      // Connect the unixsocket to the client dangling socket created
      // earlier.
      twait { connect_socket (arg->fd, res.fdpass_ok->fd, mkevent (ok)); }
      if (ok)
        stat = FLUME_OK;
    } 

    sbp->replyref (stat);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_listen (svccb *sbp)
  {
    tvars {
      listen_arg_t *a (sbp->Xtmpl getarg<listen_arg_t> ());
      flume_status_t ret;
      ptr<generic_sockend_t> s;
      ptr<p2s_sockend_t> ls;
      str tmp;
    }
    if (!(s = _fds[a->fd])) {
      ret = FLUME_ENOENT;
    } else if (!(ls = s->to_p2s ())) {
      ret = FLUME_EINVAL;
    } else {
      tmp = ls->to_str ();
      FLUMEDBG4(SOCKETS, CHATTER, "listen called on socket: %s", tmp.cstr ());
      ret = ls->listen_loop (a->queue_len);
    }
    sbp->replyref (ret);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::handle_pipe (svccb *sbp, ptr<axprt_unix> x)
  {
    pipe_arg_t *a (sbp->Xtmpl getarg<pipe_arg_t> ());
    pipe_res_t res;
    int fd;
    duplex_t duplex;

    duplex = a->writing ? DUPLEX_ME_TO_THEM : DUPLEX_THEM_TO_ME;

    if ((fd = make_uposp (&res, duplex, NULL)) >= 0) {
      FLUMEDBG3(SOCKETS, CHATTER, "sending fd");
      make_sync (fd);
      x->sendfd (fd, true);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::handle_socketpair (svccb *sbp, ptr<axprt_unix> x)
  {
    socketpair_arg_t *a (sbp->Xtmpl getarg<socketpair_arg_t> ());
    pipe_res_t res;
    int fd;

    if ((fd = make_uposp (&res, DUPLEX_FULL, a)) >= 0) {
      FLUMEDBG3(SOCKETS, CHATTER, "sending fd");
      make_sync (fd);
      x->sendfd (fd, true);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_claim_fd (svccb *sbp, ptr<axprt_unix> x)
  {
    tvars {
      claim_arg_t *arg (sbp->Xtmpl getarg<claim_arg_t> ());
      claim_res_t res;
      int fd;
    }

    twait { claim_sockend (&res, *arg, mkevent (fd)); }
    if (res.status == FLUME_OK) {
      assert (fd >= 0);
      make_sync (fd);
      x->sendfd (fd, true);
    }
    sbp->replyref (res);
  }
  
  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_register_fd (svccb *sbp)
  {
    tvars {
      register_fd_arg_t *p (sbp->Xtmpl getarg<register_fd_arg_t> ());
      flume_status_t ret;
    }

    ret = register_fd (*p);
    sbp->replyref (ret);
  }
  

  //-----------------------------------------------------------------------
  
  tamed void
  proc_t::handle_stat_file (svccb *sbp)
  {
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t> ());
      file_res_t res;
      int fl;
      int op (0);
      int proc (sbp->proc ());
      str t;
    }
    twait { 

      switch (proc) {
      case FLUME_ACCESS_FILE:
	op = FLUME_FS_ACCESS;
	fl = FLUME_OK;
        t = "access";
	break;
      case FLUME_FLUME_STAT_FILE:
	op = FLUME_FS_FLUME_STAT;
	fl = FS_OP_GETLABEL;
        t = "flume_stat_file";
	break;
      case FLUME_STAT_FILE:
	op = FLUME_FS_STAT;
	fl = FS_OP_GETSTAT;
        t = "stat_file";
	break;
      case FLUME_LSTAT_FILE:
	op = FLUME_FS_LSTAT;
	fl = FS_OP_GETSTAT;
        t = "lstat_file";
	break;
      case FLUME_READLINK:
	op = FLUME_FS_READLINK;
	fl = FS_OP_GETPATH;
        t = "readlink";
	break;

      default:
	panic ("unknown proc\n");
      }

      _rm->fsop (op, _cwd, arg, labelset ()->clone (), fl, 
		 &res, mkevent (), _filter_set); 
    }
    FLUMEDBG4(FS, CHATTER, "replying to %s (%s) with res.status %d\n", 
             t.cstr(), arg->c_args.path.cstr(), res.status);
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  ptr<capset_t>
  proc_t::fix_O_label (const x_label_t *p) 
  {
    ptr<capset_t> ret;
    if (p) {
      ret = New refcounted<capset_t> (*p);
    } else if (_ambient_fs_authority) {
      ret = _ambient_fs_authority;
    } else {
      ret = labelset ()->O();
    }
    return ret;
  }

  //-----------------------------------------------------------------------   

  ptr<labelset_t>
  proc_t::write_labelset (const file_arg_t *arg)
  {
    return labelset ()->clone (fix_O_label (arg->O_label));
  }

  //-----------------------------------------------------------------------

  ptr<labelset_t>
  proc_t::write_labelset_ep (const file_arg_t *arg, bool *checkit_p)
  {
    ptr<labelset_t> ret;
    ptr<capset_t> O = fix_O_label (arg->O_label);
    bool checkit = false;
    if (arg->ep) {
      ret = labelset_t::alloc (*arg->ep);
      ret->set_O (O);
      checkit = true;
    } else {
      ret = labelset ()->deep_clone ();
      ret->set_O (O);
    }
    if (checkit_p)
      *checkit_p = checkit;
    return ret;
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_utimes (svccb *sbp)
  {
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t> ());
      file_res_t res;
      int f (FS_OP_WRITE);
    }
    twait {
      _rm->fsop (FLUME_FS_UTIMES, _cwd, arg, write_labelset (arg),
		 f, &res, mkevent (), _filter_set);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_mkdir (svccb *sbp)
  {
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t> ());
      file_res_t res;
      int f (FS_OP_CREATE|FS_OP_WRITE);
    }
    twait { 
      _rm->fsop (FLUME_FS_MKDIR, _cwd, arg, write_labelset (arg), 
		 f, &res, mkevent (), _filter_set); 
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_rmdir (svccb *sbp)
  {
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t>());
      file_res_t res;
      int f (FS_OP_WRITE);
    }
    twait { 
      _rm->fsop (FLUME_FS_RMDIR, _cwd, arg, write_labelset (arg), 
		 f, &res, mkevent (), _filter_set); 
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_link (svccb *sbp)
  {  
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t>());
      file_res_t res;
      int f (FS_OP_WRITE|FS_OP_CREATE|FS_OP_PAIRWISE|FS_OP_SAMEDIR);
    }
    twait { 
      _rm->fsop (FLUME_FS_LINK, _cwd, arg, write_labelset (arg),
		 f, &res, mkevent (), _filter_set); 
    }
    sbp->replyref (res);
  }


  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_symlink (svccb *sbp)
  {  
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t>());
      file_res_t res;
      int f (FS_OP_WRITE|FS_OP_CREATE|FS_OP_PAIRWISE);
    }
    twait { 
      _rm->fsop (FLUME_FS_SYMLINK, _cwd, arg, write_labelset (arg),
		 f, &res, mkevent (), _filter_set); 
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_rename (svccb *sbp) 
  {  tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t>());
      file_res_t res;
      int f (FS_OP_WRITE|FS_OP_CREATE|FS_OP_PAIRWISE|FS_OP_SAMEDIR);
    }
    twait { 
      _rm->fsop (FLUME_FS_RENAME, _cwd, arg, write_labelset (arg), 
		 f, &res, mkevent (), _filter_set); 
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_close (svccb *sbp)
  {
    tvars {
      int *arg (sbp->Xtmpl getarg<int> ());
      flume_status_t res (FLUME_OK);
    }

    if (!_fds.close (*arg))
      res = FLUME_ENOENT;
    else {
      FLUMEDBG4(SOCKETS, CHATTER, "handle_close(%d)", *arg);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_dup (svccb *sbp)
  {
    tvars {
      flume_dup_arg_t *arg (sbp->Xtmpl getarg<flume_dup_arg_t> ());
      flume_status_t res (FLUME_OK);
    }

    if (arg->fd_orig < 0 || arg->fd_copy < 0) {
      res = FLUME_EINVAL;
    } else if (arg->fd_orig == arg->fd_copy) {
      res = FLUME_EDUPLICATE;
    } else if (!_fds.dup (arg->fd_orig, arg->fd_copy)) {
      res = FLUME_ENOENT;
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_unlink (svccb *sbp)
  {
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t> ());
      file_res_t res;
      int op (FS_OP_WRITE);
    }

    twait { 
      _rm->fsop (FLUME_FS_UNLINK, _cwd, arg, write_labelset (arg), 
		 op, &res, mkevent (), _filter_set); 
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_writefile (svccb *sbp)
  {
    tvars {
      file_arg_t *arg (sbp->Xtmpl getarg<file_arg_t> ());
      file_res_t res;
      str path, unjailed;
      flume_status_t st;
      int op (FS_OP_CREATE | FS_OP_WRITE);
    }

    if (arg->c_args.data.size () > fs::max_writefile_size) {
      st = FLUME_ERANGE;
    } else {
      twait { 
	_rm->fsop (FLUME_FS_WRITEFILE, _cwd, arg, write_labelset (arg),
		   op, &res, mkevent (), _filter_set, &path, &unjailed); 
      }
      FLUMEDBG4(FS, CHATTER,
	       "RM did a WRITEFILE(%s) with result = %d\n",
	       arg->c_args.path.cstr (), int (res.status));
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_dup_ctl_sock (svccb *sbp, ptr<axprt_unix> x)
  {
    flume_status_t res (FLUME_OK);
    int fd;

    if (new_ctl (&fd)) {
      assert (fd >= 0);
      make_sync (fd);
      x->sendfd (fd, true);
    } else {
      res = FLUME_EFD;
    }
    sbp->replyref (res);
  }


  //-----------------------------------------------------------------------   

  void
  proc_t::handle_get_confined (svccb *sbp)
  {
    bool r = _confined;
    sbp->replyref (r);
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_fake_confinement (svccb *sbp)
  {
    flume_status_t st = FLUME_OK;
    bool *arg = sbp->Xtmpl getarg<bool> ();
    if (*arg) {
      if (rm ()->can_fake_confinement ()) {
	set_confined (true);
	flumedbg_warn (SECURITY, "[anon process] is faking confinement!!!");
      } else {
	st = FLUME_EPERM;
	flumedbg_warn (SECURITY, 
		      "[anon process] failed to fake confinement!");
      }
    } else {
      FLUMEDBG3(PROCESS, SECURITY,
	       "[anon process] disabling confinment");
      set_confined (false);
    }
    sbp->replyref (st);
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_get_endpoint_info (svccb *sbp)
  {
    get_ep_info_res_t res (FLUME_OK);
    _lbund->get_endpoint_info (res.ok);
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_getpid (svccb *sbp)
  {
    getpid_res_t res (FLUME_OK);
    pid_t p = flmpid32 ();
    if (p < 0) {
      res.set_status (FLUME_ENOENT);
    } else {
      *res.pid = p;
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------
  
  void
  proc_t::handle_confine_me (svccb *sbp, ctl_t *ctl)
  {
    flume_confine_me_arg_t *arg = 
      sbp->Xtmpl getarg<flume_confine_me_arg_t> ();
    flume_status_t st  = FLUME_OK;
    int cli_fd  = arg->ctlsock;
    pid_t cli_unxpid;

    cli_unxpid = pid ();
    st = confine_and_fork (cli_fd, cli_unxpid, ctl, true, false);
    sbp->replyref (st);
  }

  //-----------------------------------------------------------------------   

  flume_status_t
  proc_t::confine_and_fork (int cli_fd, pid_t cli_unxpid, ctl_t *ctl, 
			    bool do_confine, bool do_fork)
  {
    flume_status_t st = FLUME_OK;
    proc_t *prc;

    if (do_confine) {
      ptr<const labelset_t> ls = labelset ();

      // MK 3.19.08: Disable the feature of not allowing integrity
      // as a result of a fork. If the parent is integritous, then the
      // child should be just as integritous, and is susceptible to the
      // same types of attack that the parent is (has mmap'ed a file that
      // becomes lower integrity).  I think, therefore, this should be
      // safe.
      if (false && ls->I () && ! ls->I ()->is_empty ()) {
	st = FLUME_NONEMPTY_INTEGRITY;

      } else if (_opens_in_progress > 0) {
	st = FLUME_ERACE;
      } else if (cli_unxpid < 0) {
	st = FLUME_ENOENT;
      } else if (!ctl) {
	st = FLUME_ENOENT;
      } else if (prctl (FLUME_PRCTL_CONFINE_ME, cli_unxpid, 
			cli_fd, ctl->fd ()) < 0) {
	st = FLUME_EPERM;
      }
    }

    if (st == FLUME_OK && do_fork) {
      ptr<proc_t> np = fork_me (cli_unxpid, ctl);
      prc = np;
    } else {
      prc = this;
    }

    if (st == FLUME_OK && do_confine) {

      // MK 3.19.08: Again, this is not needed..
      // Clear the I label in case someone snuck in.
      ptr<labelset_t> ls = prc->labelset ();
      if (false && ls->I () && !ls->I ()->is_empty ()) {
	ls->I ()->clear ();
      }

      prc->set_confined (true);
    }

    return st;
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_finish_fork (svccb *sbp, ctl_t *ctl)
  {
    flume_finish_fork_arg_t *arg = 
      sbp->Xtmpl getarg<flume_finish_fork_arg_t> ();
    flume_status_t st;

    if (!arg->confined && _confined) {
      st = FLUME_ECONFINE;
    } else {
      st = confine_and_fork (arg->ctlsock, arg->unix_pid, ctl, 
			     arg->confined, true);
    }

    sbp->replyref (st);
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_closed_files (svccb *sbp)
  {
    flume_status_t st = FLUME_OK;
    closed_files_arg_t *arg = sbp->Xtmpl getarg<closed_files_arg_t> ();
    int client_ctlsock_fd = arg->ctlsock;
    pid_t client_pid = pid ();

    if (_opens_in_progress > 0)
      st = FLUME_ERACE;
    else if (client_pid < 0) 
      st = FLUME_ENOENT;
    else if (prctl (FLUME_PRCTL_CLOSED_FILES, client_pid, 
		    client_ctlsock_fd, get_primary_ctl_fd ()) < 0)
      // The client process did not actually close all its files!
      st = FLUME_EPERM;
    else
      _lbund->clean_files ();

    sbp->replyref (st);
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::handle_debug_msg (svccb *sbp)
  {
    debug_arg_t *arg (sbp->Xtmpl getarg<debug_arg_t> ());
    warn ("flume_debug_msg (pid %d flmpid %d): %s\n", 
          pid (), flmpid32 (), arg->s.cstr ());
    sbp->replyref (FLUME_OK);
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::dispatch (svccb *sbp, ptr<axprt_unix> x, ctl_t *ctl) 
  {
    assert (sbp);
    
    FLUMEDBG4(RPC, CHATTER, "proc_t::dispatch %d\n", sbp->proc());

    switch (sbp->proc ()) {
    case FLUME_NULL:
      sbp->replyref (0);
      break;
    case SET_LABEL:
      handle_set_label (sbp);
      break;
    case GET_LABEL:
      handle_get_label (sbp);
      break;
    case NEW_HANDLE:
      handle_new_handle (sbp);
      break;
    case NEW_GROUP:
      handle_new_group (sbp);
      break;
    case OPERATE_ON_GROUP:
      handle_operate_on_group (sbp);
      break;
    case FLUME_STAT_GROUP:
      handle_stat_group (sbp);
      break;
    case SEND_CAPABILITIES:
      handle_send_capabilities (sbp);
      break;
    case VERIFY_CAPABILITIES:
      handle_verify_capabilities (sbp);
      break;
    case SET_AMBIENT_FS_AUTHORITY:
      handle_set_ambient_fs_authority (sbp);
      break;
    case OPEN_FILE:
      handle_open (sbp, x);
      break;
    case MAKE_LOGIN:
      handle_make_login (sbp);
      break;
    case LOOKUP_HANDLE_BY_NICKNAME:
      handle_lookup_by_nickname (sbp);
      break;

    case FLUME_STAT_FILE:
    case FLUME_LSTAT_FILE:
    case FLUME_FLUME_STAT_FILE:
    case FLUME_READLINK:
    case FLUME_ACCESS_FILE:
      handle_stat_file (sbp);
      break;

    case FLUME_UTIMES:
      handle_utimes (sbp);
      break;

    case FLUME_MKDIR:
      handle_mkdir (sbp);
      break;
    case FLUME_UNIXSOCKET:
      handle_unixsocket (sbp, x);
      break;
    case FLUME_REGISTER_FD:
      handle_register_fd (sbp);
      break;
    case FLUME_LISTEN:
      handle_listen (sbp);
      break;
    case FLUME_SOCKET:
      handle_socket (sbp, x);
      break;
    case FLUME_CONNECT:
      handle_connect (sbp, x);
      break;
    case FLUME_PIPE:
      handle_pipe (sbp, x);
      break;
    case FLUME_SOCKETPAIR:
      handle_socketpair (sbp, x);
      break;
    case FLUME_CLAIM_FD:
      handle_claim_fd (sbp, x);
      break;

    case FLUME_UNLINK_FILE:
      handle_unlink (sbp);
      break;

    case FLUME_RMDIR:
      handle_rmdir (sbp);
      break;
    case FLUME_RENAME:
      handle_rename (sbp);
      break;
    case FLUME_LINK:
      handle_link (sbp);
      break;
    case FLUME_SYMLINK:
      handle_symlink (sbp);
      break;
    case FLUME_CHDIR:
      handle_chdir (sbp);
      break;
    case FLUME_GETCWD:
      handle_getcwd (sbp);
      break;
    case REQ_PRIVS:
      handle_req_privs (sbp);
      break;
    case FLUME_FREEZE_LABEL:
      handle_freeze_label (sbp);
      break;
    case FLUME_THAW_LABEL:
      handle_thaw_label (sbp);
      break;
    case FLUME_NEW_NICKNAME:
      handle_new_nickname (sbp);
      break;
    case FLUME_CLOSE:
      handle_close (sbp);
      break;
    case FLUME_SUBSET_OF:
      handle_subset_of (sbp);
      break;
    case GENERATE_RANDOM_STR:
      handle_random_str(sbp);
      break;
    case FLUME_SPAWN:
      handle_spawn (sbp);
      break;
    case FLUME_WAIT:
      handle_wait (sbp);
      break;
    case FLUME_GET_SETUID_H:
      handle_get_setuid_h (sbp);
      break;
    case FLUME_DUP_CTL_SOCK:
      handle_dup_ctl_sock (sbp, x);
      break;
    case FLUME_LABELSET_TO_FILENAME:
      handle_labelset_to_filename (sbp);
      break;
    case FLUME_FILENAME_TO_LABELSET:
      handle_filename_to_labelset (sbp);
      break;
    case FLUME_APPLY_FILTER:
      handle_apply_filter (sbp);
      break;
    case FLUME_WRITEFILE:
      handle_writefile (sbp);
      break;
    case FLUME_KILL:
      handle_kill (sbp);
      break;
    case FLUME_GET_CONFINED:
      handle_get_confined (sbp);
      break;
    case FLUME_FAKE_CONFINEMENT:
      handle_fake_confinement (sbp);
      break;
    case FLUME_GET_ENDPOINT_INFO:
      handle_get_endpoint_info (sbp);
      break;
    case FLUME_GET_LABELSET:
      handle_get_labelset (sbp);
      break;
    case FLUME_CLOSED_FILES:
      handle_closed_files (sbp);
      break;
    case FLUME_GETPID:
      handle_getpid (sbp);
      break;
    case FLUME_DUP:
      handle_dup (sbp);
      break;
    case FLUME_CONFINE_ME:
      handle_confine_me (sbp, ctl);
      break;
    case FLUME_FINISH_FORK:
      handle_finish_fork (sbp, ctl);
      break;
    case FLUME_SETEPOPT:
      handle_setepopt (sbp);
      break;
    case FLUME_DEBUG_MSG:
      handle_debug_msg (sbp);
      break;
    default:
      sbp->reject (PROC_UNAVAIL);
      break;
    }
  }

};

