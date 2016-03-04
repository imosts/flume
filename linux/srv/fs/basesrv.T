
// -*-c++-*-
#include "fs.h"
#include "flume_fs_prot.h"
#include "tame_autocb.h"
#include "parseopt.h"
#include "asyncutil.h"

namespace fs { 

  //-----------------------------------------------------------------------

  static bool
  is_ok_open (flume_status_t s)
  {
    return s == FLUME_OK || s == FLUME_LABEL_OK;
  }

  //-----------------------------------------------------------------------

  int
  base_srv_t::boil_down_flags (int unix_flags)
  {
    int rw = 0;
    if (flags_for_write (unix_flags)) rw |= WRITING;
    if (flags_for_read (unix_flags)) rw |= READING;
    return rw;
  }

  //-----------------------------------------------------------------------

  str 
  base_srv_t::pathfix (const str &s) const
  {
    str r = top_level_fix (s);
    if (r) r = dedotify (r);
    if (r) r = jail2real (r);
    return r;
  }

  //-----------------------------------------------------------------------
  
  base_srv_t::base_srv_t (const cfg_t &o) 
    : jailable_t (o._root),
      _cfg (o), _devid (0), _next_cwd_token (1) {}

  //-----------------------------------------------------------------------
  
  base_srv_t::~base_srv_t () {}
  
  //-----------------------------------------------------------------------

  bool
  base_srv_t::check_deviceid ()
  {
    struct stat sb;
    str root = jail2real ("/");
    int rc = stat (root.cstr (), &sb);
    if (rc < 0) {
      warn ("stat on %s failed: %m\n", root.cstr ());
      return false;
    } else {
      _devid = sb.st_dev;
    }
    return true;
  }

  //-----------------------------------------------------------------------

  bool
  base_srv_t::setuid ()
  {
    bool ret = true;
    if (get_uid () == 0) {
      ret = _cfg.setuid ();
    }
    return ret;
  }

  //-----------------------------------------------------------------------
  
  tamed void
  base_srv_t::init (cbb cb)
  {
    tvars {
      bool ret (false);
    }

    if (!isunixsocket (0)) {
      warn << "File descriptor 0 is not a Unix Socket, as expected.\n";
      warn << "Check that this program was launched by flumerm.\n";
    } else if (!check_deviceid ()) {
      warn << "Cannot get the device ID for this mountpoint.\n";
    } else if (!v_init ()) {
      warn << "Virtual initialization failed.\n";
    } else {
      twait { _cfg.init_idd (mkevent (ret)); }
      if (!ret) {
	warn << "Cannot connect to IDD on " << _cfg.idd ()->to_str () << "\n";
      } else if (!chroot ()) {
	warn ("chroot operation failed: %m\n");
	ret = false; 
      } else if (!setuid ()) {
	warn ("setuid operation failed: %m\n");
	ret = false;
      } else {
	global_idd_init (_cfg.idd (), _cfg.handle_seed ());
      }
    }
    cb->trigger (ret);
  }
  
  //-----------------------------------------------------------------------
  
  void
  base_srv_t::run ()
  {

#ifndef __linux__
    flmsockopt (0);
#endif

    _x = axprt_unix::alloc (0);
    _cli = aclnt::alloc (_x, flume_fs_prog_1);
    _srv = asrv_delayed_eof::alloc (_x, flume_fs_prog_1, 
				    wrap (this, &base_srv_t::dispatch));
  }
  
  //-----------------------------------------------------------------------
  
  void
  base_srv_t::shutdown ()
  {
    warn << "Caught EOF from rm; shutting down...\n";
    delete this;
    exit (0);
  }

  //-----------------------------------------------------------------------

  static bool
  parent_dir (str in, str *pd, str *file, bool fix = true)
  {
    static rxx x ("/+");
    vec<str> path;

    if (fix && !(in = dedotify (in)))
      return false;

    split (&path, x, in);

    if (path.size () == 0)
      return false;

    if (path[path.size () - 1].len () == 0)
      path.pop_back ();

    if (path.size () == 0) {
      *pd = NULL;
      *file = "/";

    } else {
      *file = path.pop_back ();
      
      strbuf b;
      if (in[0] == '/')
	b << "/";
      for (size_t i = 0; i < path.size (); i++) {
	if (i > 0) b << "/";
	b << path[i];
      }
      *pd = b;
    }
    return true;
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::set_labels_by_fn (int dfd, ino_t ino, const str &fn,
				const labelset_t *ls, int which,
				flume_status_cb_t cb)
  {
    tvars {
      frozen_labelset_t fls;
      flume_status_t st (FLUME_OK);
    }

    twait { freeze_labels (ls, &fls, which, mkevent (st)); }
    if (st == FLUME_OK) {
      twait { set_frozen_labelset_by_fn (dfd, fn, fls, mkevent (st)); }
    }

    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::stat_get_labels_by_fn (int dfd, ino_t ino, const str &fn, 
				     file_res_t *res, cbv cb,
				     labelset_t *lsp)
  {
    tvars {
      frozen_labelset_t fls;
      flume_status_t st (FLUME_OK);
      int which (LABEL_ALL);
      ptr<const labelset_t> def_ls;
      bool rootflag;
    }

    rootflag = (dfd == -1 && (fn == "" || is_root (fn)));

    if ((def_ls = _cfg.def_ls ())) {
      *lsp = *def_ls;
    } else if (rootflag && _cfg._root_ls) {
      *lsp = *_cfg._root_ls;
    } else {
      
      twait { get_frozen_labelset_by_fn (dfd, fn, &fls, mkevent (st)); }
      if (st == FLUME_OK) {
	twait { thaw_labels (&fls, lsp, which, mkevent (st)); }
      }
    }

    if (st== FLUME_OK) {
      res->set_status (FLUME_LABEL_OK);
      lsp->to_xdr (res->label);
    } else {
      res->set_status (st);
    }

    cb->trigger ();
  }

  //-----------------------------------------------------------------------
  
  tamed void
  base_srv_t::handle_writefile (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      flume_status_t st;
      int fd;
      size_t ln (arg->c_args.data.size ());
      mstr m (ln);
    }
    
    twait { do_open (arg, &res, mkevent (fd)); }
    if (is_ok_open (res.status)) {
      assert (fd >= 0);
      memcpy (m.cstr (), arg->c_args.data.base (), ln);

      twait { writefile_impl (fd, m, mkevent (st)); }
      res.set_status (st);
      close (fd);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::prepare_read (const str &path, str *dd_path_p, str *pd_p,
			    str *file_p, int *fd_d_p, flume_status_cb_t cb)
  {
    tvars {
      str dd_path;
      int fd_d (-1);
      flume_status_t stat;
      str p_tmp;
    }

    if (!(p_tmp = top_level_fix (path))) {
      stat = FLUME_EPATH;
    } else if (!(dd_path = dedotify (p_tmp))) {
      stat = FLUME_EPATH;
    } else if (!parent_dir (dd_path, pd_p, file_p, false)) {
      stat = FLUME_EPATH;
    } else if (!*pd_p) {
      stat = FLUME_OK;
    } else {
      twait { open (jail2real (*pd_p), O_RDONLY, 0, mkevent (fd_d)); }
      if (fd_d < 0) {
	stat = FLUME_ENOENT;
      } else {
	stat = FLUME_OK;
      }
    }
    *dd_path_p = dd_path;
    *fd_d_p = fd_d;
    cb->trigger (stat);
  }


  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_stat (svccb *sbp)
  {
    tvars {
      holdvar file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      flume_status_t stat;
      int fd_d (-1);
      str file, pd;
      str path (arg->c_args.path);
      int mode (arg->c_args.mode);
      filterset_t fs (arg->filters);
      str dd_path;
      ptr<labelset_t> ls_proc (labelset_t::alloc (arg->proc));
      labelset_t ls_dir, ls_file;
      int which (LABEL_ALL);
      struct stat sb;
      str lnk;
      bool reset_res (true);
      bool use_lstat (sbp->proc () != FLUME_FS_STAT);
      bool flume_stat (sbp->proc () == FLUME_FS_FLUME_STAT);
      bool unix_stat (sbp->proc () == FLUME_FS_LSTAT ||
		      sbp->proc () == FLUME_FS_STAT);
      bool access (sbp->proc() == FLUME_FS_ACCESS);
      bool dofilter (!access || (mode & (R_OK | X_OK | F_OK)));
    }

    twait { prepare_read (path, &dd_path, &pd, &file, &fd_d, mkevent (stat)); }
    if (fd_d >= 0) {
      twait { 
	get_labels (fd_d, is_root (pd), &ls_dir, which, mkevent (stat), pd); 
      }
      if (dofilter && !fs.apply (&ls_dir)) {
	stat = FLUME_EFILTER;
      } else if (stat == FLUME_OK && !( ls_dir <= *ls_proc)) {
	stat = FLUME_EPERM;
      }
    }

    if (stat == FLUME_OK && access) {
      twait { access_impl (fd_d, file, mode, mkevent (stat)); }
      if (stat == FLUME_OK && _cfg._readonly && (mode & W_OK)) {
	stat = FLUME_EROFS;
      }
    }

    if (stat == FLUME_OK) {
      
      if (sbp->proc () == FLUME_FS_READLINK) {
	  
	twait { readlink_impl (fd_d, file, &lnk, mkevent (stat)); }
	if (stat == FLUME_OK) {
	  res.set_status (FLUME_PATH_OK);
	  *res.path = lnk;
	  reset_res = false;
	}
	
      } else {
	// FS_FLUME_STAT, FS_STAT, FS_LSTAT or FS_ACCESS
	twait { stat_impl (fd_d, file, &sb, mkevent (stat), use_lstat); }
	if (stat == FLUME_OK) {
	  reset_res = false;
	  
	  if (!use_lstat && S_ISLNK(sb.st_mode)) {
	    reset_res = true;
	    stat = FLUME_ERR;
	    warn << "Got unexpected symlink back: " << dd_path << "\n";
	    
	    // Symlinks have the label of the parent directory!
	    // Also throw in the case of a public/readonly FS
	    // since we can use the parent dir's label here too
	    // (this is an optimization).
	  } else if (S_ISLNK (sb.st_mode) || S_ISSOCK(sb.st_mode) ||
		     _cfg.def_ls ()) {
	    
	    // If we're just checking the labels (i.e., flume_stat)
	    // then just return what the parent dir was
	    if (flume_stat) {
	      res.set_status (FLUME_LABEL_OK);
	      ls_dir.to_xdr (res.label);
	    }
	    
	  } else {
	    // This case is for regular files; need to open the file up!
	    twait { 
	      stat_get_labels_by_fn (fd_d, sb.st_ino, file, &res, 
				     mkevent (), &ls_file); 
	    }

	    if (dofilter && !fs.apply (&ls_file)) {
	      stat = FLUME_EFILTER;
	    } else if (res.status == FLUME_LABEL_OK) {
	      // Special case: the user wants a Unix-style stat, but
	      // the permissions on the file won't allow it, so
	      // need to say no-can-do.
	      if (unix_stat && !(ls_file <= *ls_proc)) {
		stat = FLUME_EPERM;
		reset_res = true;

		// For the access(2) systemcall, we need to check
		// that the access mode is OK with what the file
		// actually says.
	      } else if (access) {
		reset_res = true;
		if ( ((mode & W_OK) && !(*ls_proc <= ls_file)) ||
		     ((mode & (R_OK|X_OK)) && !(ls_file <= *ls_proc))) {
		  stat = FLUME_EPERM;
		} else {
		  stat = FLUME_OK;
		}
	      }
	    }
	  }
	  
	  if (stat == FLUME_OK && unix_stat) {
	    // otherwise, we have adequate permission to return the
	    // socket (or link's) metadata
	    res.set_status (FLUME_STAT_OK);
	    stat2xdr (sb, res.stat);
	  }
	}
      }
      
    } else if (stat == FLUME_ENOENT || stat == FLUME_EPERM) {
      
      // Slow path in the case of noentry, since we need to tell
      // whether it was a ENOENT or an EPERM
      twait { 
	fswalk (dd_path, O_RDONLY, 0, ls_proc, mkevent (stat), READING); 
      }
      
      // maybe it change from underneath us.
      if (stat == FLUME_OK) 
	stat = FLUME_ENOENT;
    } 
    
    if (reset_res) 
      res.set_status (stat);
    
    if (fd_d >= 0) close (fd_d);
    
    sbp->replyref (res);
  }
    
  //-----------------------------------------------------------------------
  
  tamed void
  base_srv_t::handle_rmdir (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      flume_status_t stat;
      ptr<t_lock_handle_t> plh;
      str file;
      int pfd (-1);
    }

    twait { prepare_modify (arg, &file, &pfd, &plh, mkevent (stat)); }
    if (stat == FLUME_OK) {
      twait { rmdir_impl (pfd, file, mkevent (stat)); }
    }
    plh = NULL;
    if (pfd >= 0) close (pfd);
    res.set_status (stat);

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_mkdir (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      ptr<labelset_t> creat;
      ptr<t_lock_handle_t> plh;
      str file;
      int pfd (-1);
      int mode (arg->c_args.mode);
      flume_status_t stat;
    }

    twait {
      prepare_create (arg, &res, &file, &pfd, &plh, &creat, mkevent (),
		      MKDIR);
    }
    if (res.status == FLUME_OK) {
      twait { mkdir_in (pfd, file, mode, creat, mkevent (stat)); }
      res.set_status (stat);
    }
    plh = NULL;
    if (pfd >= 0) close (pfd);
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_link_or_rename (svccb *sbp, bool rn)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      ptr<labelset_t> creat;
      ptr<t_lock_handle_t> plh;
      str file, p_from;
      int pfd (-1);
      flume_status_t stat;
    }

    if (!arg->c_args.path_src || !(p_from = *arg->c_args.path_src) ||
	!fs::is_legal_filename (p_from)) {
      stat = FLUME_EPATH;
    } else {
      twait {
	prepare_create (arg, &res, &file, &pfd, &plh, &creat, mkevent ());
      }
      if (res.status == FLUME_OK) {
	twait { link_or_rename_impl (pfd, file, p_from, rn, mkevent (stat)); }
	res.set_status (stat);
      }
    }
    plh = NULL;
    if (pfd >= 0) close (pfd);
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_symlink (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      flume_status_t stat;
      ptr<labelset_t> creat;
      ptr<t_lock_handle_t> plh;
      str file, p_from;
      int pfd (-1);
    }

    if (!arg->c_args.path_src || !(p_from = *arg->c_args.path_src)) {
      stat = FLUME_EPATH;
    } else {
      twait {
	// Note that symlinks must have the same label as the parent
	// directory.
	prepare_create (arg, &res, &file, &pfd, &plh, &creat, mkevent (), 
			EQUALS); 
      }
      if (res.status == FLUME_OK) {
	twait { symlink_impl (pfd, file, p_from, mkevent (stat)); }
	res.set_status (stat);
      }
    }
    plh = NULL;
    if (pfd >= 0) close (pfd);
    sbp->replyref (res);
  }
  
  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_unixsocket (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      flume_status_t stat;
      ptr<labelset_t> creat;
      ptr<t_lock_handle_t> plh;
      str file;
      int pfd (-1);
      int fd (-1);
      int mode (arg->c_args.mode);
      struct stat sb;
    }

    twait {
      prepare_create (arg, &res, &file, &pfd, &plh, &creat, mkevent (), 
		      EQUALS);
    }
    if (res.status == FLUME_OK) {
      twait { mksock_impl (pfd, file, mode, mkevent (stat, fd), &sb); }
      if (stat == FLUME_OK && fd >= 0) {
	// might be a race, since we didn't lock the socket before we
	// were able to set its label...
	twait { set_labels_by_fn (pfd, sb.st_ino, file, creat, 
				  LABEL_ALL, mkevent (stat)); }
	if (stat != FLUME_OK) {
	  warn << "Set-labels on new socket failed: " << int (stat) << "\n";
	}
      }
      res.set_status (stat);
    }
    plh = NULL;
    if (pfd >= 0) close (pfd);

    if (res.status == FLUME_OK) {
      if (fd < 0) {
	res.set_status (FLUME_EINVAL);
      } else {
	_x->sendfd (fd);
        res.set_status (FLUME_LABEL_OK);
        creat->to_xdr (res.label);
      }
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------
  
  tamed void
  base_srv_t::check_unixconnect (const str &path, const labelset_t *proc,
				 str *fp, open_cb_t cb,
				 const filterset_t &fs)
  {
    tvars {
      flume_status_t stat;
      str dir, file;
      int fd (-1);
      labelset_t ls_file;
      int which (LABEL_NO_O);
    }

    if (!parent_dir (path, &dir, &file)) {
      stat = FLUME_EPATH;
    } else if (!dir) {
      stat = FLUME_EINVAL;
    } else {

      // XXX
      // Eventually use open_and_check here; but that will only work
      // if we're using Ghetto EAs, since we can't set real EAs on
      // sockets.
      // XXX
      twait { open (jail2real (dir), O_RDONLY, 0, mkevent (fd)); }

      if (fd < 0) {
	// slow path to figure out if was ENOENT or EPERM that burned us
	twait { fswalk (dir, O_RDONLY, 0, proc, mkevent (stat), READING); }
      } else {
	twait { 
	  get_labels (fd, is_root (dir), &ls_file, which, 
		      mkevent (stat), dir); 
	}
	if (stat == FLUME_OK) {
	  if (!fs.apply (&ls_file)) {
	    stat = FLUME_EFILTER;
	  } else if (!(ls_file <= *proc)) {
	    stat = FLUME_EPERM;
	  }
	}
      }
    }
    if (fp) *fp = file;

    if (stat != FLUME_OK && fd >= 0) {
      close (fd);
      fd = -1;
    }

    cb->trigger (stat, fd);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_unixconnect (svccb *sbp)
  {
    tvars {
      holdvar file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      str path (arg->c_args.path);
      ptr<labelset_t> proc (labelset_t::alloc (arg->proc));
      flume_status_t stat;
      int pfd, sfd;
      str file;
      filterset_t fs (arg->filters);
    }

    twait { check_unixconnect (path, proc, &file, mkevent (stat, pfd), fs); }
    if (stat == FLUME_OK) {
      twait { unixconnect_impl (pfd, file, mkevent (stat, sfd)); }
      close (pfd);
      if (stat == FLUME_OK) {
        stat = FLUME_LABEL_OK;
	_x->sendfd (sfd);
      }
    }
    res.set_status (stat);
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_utimes (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t res;
      str p2;
      flume_status_t stat (FLUME_OK);
      int fd;
      ptr<t_lock_handle_t> lh;
      ptr<labelset_t> pl (labelset_t::alloc (arg->proc));
      ptr<labelset_t> vl (arg->xls ? labelset_t::alloc (*arg->xls) : NULL);
      int rw (0);
      int fl;
      tame::lock_t::mode_t lm;
      filterset_t fs (arg->filters);
      x_utimes_t *ut (arg->c_args.utimes);
    }

    res.set_status (FLUME_OK);

    if (!(p2 = pathfix (arg->c_args.path))) {
      stat = FLUME_EPATH;
    } else {
      rw = WRITING;
      fl = O_WRONLY;
      lm = tame::lock_t::EXCLUSIVE;
      
      twait { 
	open_and_check (p2, fl, 0, pl, fs, mkevent (stat, fd), 
			rw, vl, &lh, lm);
      }
      if (stat == FLUME_OK) {
	assert (fd >= 0);
	twait { utimes_impl (fd, ut, mkevent (stat)); }
      }
    }
    
    if (stat != FLUME_OK && res.status == FLUME_OK) {
      res.set_status (stat);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_lutimes (svccb *sbp)
  {
    tvars {
      file_res_t res (FLUME_UNHANDLED);
    }
    sbp->replyref (res);
  }


  //-----------------------------------------------------------------------
  
  void
  base_srv_t::dispatch (svccb *sbp)
  {
    if (!sbp) {
      shutdown ();
      return;
    }
    switch (sbp->proc ()) {
    case FLUME_FS_NULL:
      sbp->replyref (0);
      break;
    case FLUME_FS_OPEN:
      handle_open (sbp);
      break;

    case FLUME_FS_WRITEFILE:
      handle_writefile (sbp);
      break;

    case FLUME_FS_FLUME_STAT:
    case FLUME_FS_READLINK:
    case FLUME_FS_LSTAT:
    case FLUME_FS_STAT:
    case FLUME_FS_ACCESS:
      handle_stat (sbp);
      break;

    case FLUME_FS_UTIMES:
      handle_utimes (sbp);
      break;

    case FLUME_FS_LUTIMES:
      handle_lutimes (sbp);
      break;

    case FLUME_FS_MKDIR:
      handle_mkdir (sbp);
      break;
    case FLUME_FS_RMDIR:
      handle_rmdir (sbp);
      break;
    case FLUME_FS_UNIXSOCKET:
      handle_unixsocket (sbp);
      break;
    case FLUME_FS_UNIXCONNECT:
      handle_unixconnect (sbp);
      break;

    case FLUME_FS_UNLINK:
      handle_unlink (sbp);
      break;

    case FLUME_FS_LINK:
      handle_link_or_rename (sbp, true);
      break;

    case FLUME_FS_SYMLINK:
      handle_symlink (sbp);
      break;

    case FLUME_FS_RENAME:
      handle_link_or_rename (sbp, false);
      break;

    case FLUME_FS_SHUTDOWN:
      handle_shutdown (sbp);
      break;

    case FLUME_FS_READ_FILTER:
      handle_read_filter (sbp);
      break;

    default:
      sbp->reject (PROC_UNAVAIL);
      break;
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_shutdown (svccb *sbp)
  {
    tvars {
      cwd_tok_t *arg (sbp->Xtmpl getarg<cwd_tok_t> ());
      flume_status_t res;
      int *i;
    }
    i = _cwd_tokens[*arg];
    if (i) {
      close (*i);
      res = FLUME_OK;
    } else {
      res = FLUME_ENOENT;
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void 
  base_srv_t::handle_open (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_res_t ret (FLUME_ENOENT);
      int fd (-1);
    } 

    twait { do_open (arg, &ret, mkevent (fd)); }

    if (is_ok_open (ret.status) && fd >= 0) {
      if (arg->options & int (FS_OP_FDPASS)) {
	_x->sendfd (fd);
      } else {
	close (fd);
      }
    }
    sbp->replyref (ret);

  }

  //-----------------------------------------------------------------------
  
  tamed void
  base_srv_t::do_open (const file_arg_fs_t *arg, file_res_t *ret, cbi cb)
  {
    tvars {
      flume_status_t stat;
      int flags (arg->c_args.flags);
      int fd (-1);
    }
    
    if (flags & O_CREAT) {

      // In the case that the CREAT flags has been specified, we first
      // need to check if the file already exists, and if the user didn't
      // specify O_EXCL.  In this case, it suffices to ignore the 
      // CREAT flag; thus, we AND it out of flags, and then try to open
      // the file as if it already exists (without O_CREAT).  If this
      // open fails, it's still posible to create the file, and we
      // try that too.
      flags &= ~O_CREAT;
      stat = FLUME_ENOENT;
      if (!(flags & O_EXCL) && flags_for_write (flags)) {
	twait { handle_open_existing (arg, ret, mkevent (fd), flags); }
      }

      // We get ENOENT here in one of two cases: (1) if flags contained
      // O_CREAT|O_EXCL; or (2) if the O_EXCL flags wasn't supplied, but
      // the attempt to open the file failed.
      if (ret->status == FLUME_ENOENT) {
	twait { handle_open_creat (arg, ret, mkevent (fd) ); }
      }

    } else {
      twait { handle_open_existing (arg, ret, mkevent (fd)); }
    }

    cb->trigger (fd);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_open_existing (const file_arg_fs_t *arg, 
				    file_res_t *res,
				    cbi cb, int flags,
				    ptr<eval::ctx_t> ctx)
  {
    tvars {
      int fd (-1);
      flume_status_t stat (FLUME_ENOENT);
      str f;
      int flg (flags >= 0 ? flags : arg->c_args.flags);
      int mode (arg->c_args.mode);
      ptr<labelset_t> ls (labelset_t::alloc (arg->proc));
      ptr<labelset_t> vrfy (arg->xls ? labelset_t::alloc (*arg->xls) : NULL);
      filterset_t fs (arg->filters);
      str p_tmp;
      labelset_t file_label;
    }

    if (!(p_tmp = top_level_fix (arg->c_args.path))) {
      stat = FLUME_EPATH;
    } else if (!(f = dedotify (p_tmp))) {
      stat = FLUME_EPATH;
    } else {
      twait { 
	open_and_check (f, flg, mode, ls, fs, mkevent (stat, fd), 
			boil_down_flags (flg), vrfy, NULL, 
			tame::lock_t::SHARED, 
			ctx, &file_label);
      }
    }

    if (stat == FLUME_OK) {
      res->set_status (FLUME_LABEL_OK);
      file_label.to_xdr (res->label);
    } else {
	  res->set_status (stat);
	}

    cb->trigger (fd);
  }

  //-----------------------------------------------------------------------


  tamed void 
  base_srv_t::handle_unlink (svccb *sbp)
  {
    tvars {
      holdvar file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      flume_status_t stat;
      file_res_t ret (FLUME_ENOENT);
      str pd, file;
      int pfd;
      ptr<labelset_t> proc (labelset_t::alloc (arg->proc));
      ptr<labelset_t> vrfy (arg->xls ? labelset_t::alloc (*arg->xls) : NULL);
      ptr<t_lock_handle_t> plh;
      str p_in (arg->c_args.path);
      filterset_t fs (arg->filters);
    } 

    if (_cfg._readonly) {
      stat = FLUME_EPERM;
    } else if (!parent_dir(p_in, &pd, &file)){
      stat = FLUME_EPATH;
    } else{
      twait {
	open_and_check(pd, O_RDONLY, 0, proc, fs, mkevent (stat, pfd), 
		       WRITING | READING, vrfy, &plh, tame::lock_t::EXCLUSIVE);
      }
      if (stat == FLUME_OK && pfd >= 0) {
	twait{
	  unlink_impl(pfd, file, mkevent (stat));
	}
	close(pfd);
      }
    }
    //releases the lock handle
    plh = NULL;
    ret.set_status (stat);
    sbp->replyref (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::get_labels (int fd, bool is_root,
			  labelset_t *ls, int which,
			  flume_status_cb_t cb, const str &desc,
			  ptr<t_lock_handle_t> *lhp, tame::lock_t::mode_t mode)
  {
    tvars {
      frozen_labelset_t fls;
      flume_status_t res (FLUME_OK);
      ptr<t_lock_handle_t> lh;
      ptr<const labelset_t> dls;
    }

    if ((dls = _cfg.def_ls ())) {
      *ls = *dls;
    } else if (is_root && _cfg._root_ls) {
      *ls = *_cfg._root_ls;
    } else {
      if (lhp) {
	twait { acquire_lock (fd, desc, mode, mkevent (res, lh)); }
      }
      if (res == FLUME_OK) {
	twait { get_frozen_labelset (fd, &fls, mkevent (res)); }
	
	if (lhp) {
	  *lhp = lh;
	  lh = NULL;
	}
	
	if (res == FLUME_OK) {
	  twait { thaw_labels (&fls, ls, which, mkevent (res)); }
	}
      }
    }
    cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::set_labels (int fd, const labelset_t *ls, int which,
			  flume_status_cb_t cb, const str &fn, int pfd)
  {
    tvars {
      flume_status_t res (FLUME_OK);
      ptr<t_lock_handle_t> lh;
      frozen_labelset_t fls;
    }

    // Need to acquire lock ASAP to mitigate (non-leaky) race conditions
    twait { 
      acquire_lock (fd, fn, tame::lock_t::EXCLUSIVE, mkevent (res, lh)); 
    }

    if (res == FLUME_OK) {
      twait { freeze_labels (ls, &fls, which, mkevent (res)); }
      if (res == FLUME_OK) {
	twait { set_frozen_labelset (fd, fls, mkevent (res)); }
      }
    }

    lh = NULL;

    cb->trigger (res);
  }

  //-----------------------------------------------------------------------
  
  tamed void
  base_srv_t::thaw_labels (const frozen_labelset_t *in,
			   labelset_t *out, int which,
			   flume_status_cb_t cb)
  {
    tvars {
      flume_status_t res (FLUME_OK);
      ptr<label_t> O_tmp;
    }
    
    twait {
      if (which & LABEL_S) 
	thaw_label (&in->S, out->S_pointer (), &res, mkevent ()); 
      if (which & LABEL_I) 
	thaw_label (&in->I, out->I_pointer (), &res, mkevent ()); 
      if (which & LABEL_O) 
	thaw_label (&in->O, &O_tmp, &res, mkevent ()); 
    }

    if (O_tmp) 
      out->set_O (New refcounted<capset_t> (*O_tmp));

    cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::thaw_label (const frozen_label_t *in, ptr<label_t> *out,
			  flume_status_t *res, cbv cb)
  {
    tvars {
      flume_status_t r;
    }
    twait { _cfg.idd ()->thaw (in, out, mkevent (r)); }
    *res = r;
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::freeze_labels (const labelset_t *in, frozen_labelset_t *out,
			     int which, flume_status_cb_t cb)
  {
    tvars {
      flume_status_t res (FLUME_OK);
    }
    twait {
      if (which & LABEL_S) freeze_label (in->S(), &out->S, &res, mkevent ()); 
      if (which & LABEL_I) freeze_label (in->I(), &out->I, &res, mkevent ());
      if (which & LABEL_O) freeze_label (in->O(), &out->O, &res, mkevent ());
    }
    cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::freeze_label (const label_t *in, frozen_label_t *out,
			    flume_status_t *res, cbv cb)
  {
    tvars {
      flume_status_t r;
    }
    twait { _cfg.idd ()->freeze (in, out, mkevent (r)); }
    *res = r;
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::open (const str &fn, int flags, int mode, cbi cb)
  {
    tvars {
      flume_status_t res;
      int fd;
    }
    twait { open_impl (-1, fn, flags, mode, mkevent (res, fd), NULL); }
    cb->trigger (fd);
  }

  //-----------------------------------------------------------------------

  // check if a given pathname is the root of an integrity FS
  bool
  base_srv_t::is_integrity_fs_root (const str &d)
  {
    return is_root (d) && _cfg._integrity_ns;
  }

  //-----------------------------------------------------------------------

  bool
  base_srv_t::integrity_ns_check (const str &fn, const labelset_t &proc,
				  const labelset_t &file)
  {
    // There's a slight carve-out in the integrity NS, since 
    // processes can mkdir in "/" even if their intergrity labels
    // shouldn't allow it.
    return (is_integrity_fs_root (fn) && 
	    proc.can_send_S (file) && file.can_send_S (proc));
  }


  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::open_and_check (const str &f, int flags, int mode,
			      ptr<labelset_t> proc,
			      const filterset_t &fs,
			      open_cb_t cb,
			      int rw,
			      ptr<labelset_t> vrfy,
			      ptr<t_lock_handle_t> *lhp, 
			      tame::lock_t::mode_t lmode,
			      ptr<eval::ctx_t> ctx,
			      labelset_t *filep)
  {
    tvars {
      int fd (-1);
      flume_status_t ret;
      int rc;
      bool writing (rw & base_srv_t::WRITING);
      bool reading (rw & base_srv_t::READING);
      bool eq ( rw & base_srv_t::EQUALS );
      bool creat (rw & base_srv_t::CREATE);
      bool all_writes_ok (rw & base_srv_t::ALL_WRITES_OK);
      bool dofilter (!(rw & base_srv_t::NOFILTER));
      bool socket (rw & base_srv_t::SOCKET);
      str jfn;
      int which (LABEL_S | LABEL_I | (writing ? LABEL_O : 0));
      labelset_t file;
      ptr<mhmgr_t> hmgr (mhmgr_t::alloc (proc, NULL));
    }

    if (!filep)
      filep = &file;

    jfn = jail2real (f);

    if (writing && _cfg._readonly) {
      ret = FLUME_EROFS;
    } else {
      twait { open (jfn, flags_make_non_mutate (flags), mode, mkevent (fd)); }
      if (fd < 0) {
	// Take the slow path to see if it was a ENOENT or an EPERM.
	twait { fswalk (jfn, flags, mode, proc, mkevent (ret), rw, ctx); }
      } else {
	twait { 
	  get_labels (fd, is_root (f), filep, which, mkevent (ret), 
		      jfn, lhp, lmode); 
	}

	if (!filep->filled (which)) {
	  ret = FLUME_EATTR;
	} else if (dofilter && !writing && !fs.apply (filep)) {
	  ret = FLUME_EFILTER;
	} else if (ret != FLUME_OK) {
	  /* noop */
	} else if (!creat && vrfy && (!(*filep <= *vrfy))) {
	  ret = FLUME_ERACE;
	} else if (reading && !(*filep <= *proc)) {
	  if (ctx) {
	    ctx->error ("For reading '", f, "', expected file's labelset ",
			*filep, " to be less than the process's ", *proc);
	  }
	  ret = FLUME_EPERM;
	} else if (!writing) {
	  ret = FLUME_OK;
	} else if (!all_writes_ok && !(*proc <= *filep)) {
	  if (ctx) {
	    ctx->error ("For writing '", f, 
			"', expected the proc's labelset ",
			*proc, " to be less than the file's ", *filep);
	  }
	  ret = FLUME_EPERM;
	} else if (eq && !(*filep <= *proc)) {
	  if (ctx) {
	    ctx->error ("For file '", f , "', expected equality between "
			"this file's label ", *filep, 
			" and the process's ", *proc);
	  }
	  ret = FLUME_EPERM;
	}
      }
    }
    if ((writing || socket) && ret == FLUME_OK) {
      // When checking intersections, make sure the flat label is on
      // the LHS, since we only explore the group graph on the RHS.
      twait { hmgr->cap_intersects (filep->O(), proc->O(), mkevent (rc)); }
      if (rc <= 0) {
	if (ctx) {
	  ctx->error ("For file '", f, 
		      "', expected one of the capabilities in ", 
		      filep->O(), " to be in the process's ownership"
		      "label ", proc->O ());
	}
	ret = FLUME_EPERM;
      }
    }
    
    if (flags_mutates (flags) && ret == FLUME_OK && fd >= 0) {
      assert (!socket);
      if (ftruncate (fd, 0) < 0) {
        if (ctx) {
          ctx->error ("For file '", f, 
                      "', could not truncate file");
        }
        ret = FLUME_ERR;
      }
    }

    if (ret != FLUME_OK && fd >= 0) {
      close (fd);
      fd = -1;
    }

    cb->trigger (ret, fd);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::acquire_lock_by_name (const str &file, 
				    tame::lock_t::mode_t mode,
				    acquire_cb_t cb)
  {
    tvars {
      struct stat sb;
      ino_t ino;
      flume_status_t ret;
      ptr<t_lock_handle_t> lh;
      int rc;
    }

    if ((rc = stat (file.cstr (), &sb)) < 0) {
      warn ("Cannot stat %s: %m\n", file.cstr ());
      ret = FLUME_EINVAL;
    } else {
      ino = sb.st_ino;
      twait { acquire_lock_by_ino (ino, mode, mkevent (ret, lh)); }
    }
    cb->trigger (ret, lh);
    lh = NULL;
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::acquire_lock_by_ino (ino_t ino, 
				   tame::lock_t::mode_t mode,
				   acquire_cb_t cb)
  {
    tvars {
      ptr<t_lock_handle_t> lh;
      flume_status_t ret;
    }

    twait { _locks.acquire (&lh, ino, mode, mkevent ()); }
    ret = FLUME_OK;
    cb->trigger (ret, lh);
    lh = NULL;
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::acquire_lock (int fd, const str &what, 
			    tame::lock_t::mode_t mode, acquire_cb_t cb)
  {
    tvars {
      struct stat sb;
      ino_t ino;
      flume_status_t ret;
      ptr<t_lock_handle_t> lh;
      int rc;
    }
	
    if ((rc = fstat (fd, &sb)) < 0) {
      warn ("Cannot stat %s: %m\n", what.cstr ());
      ret = FLUME_EINVAL;
    } else {
      ino = sb.st_ino;
      twait { acquire_lock_by_ino (ino, mode, mkevent (ret, lh)); }
    }
    cb->trigger (ret, lh);
    lh = NULL;
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::fswalk (const str &file, int flags, int mode,
		      const labelset_t *proc, flume_status_cb_t cb,
		      int opts, ptr<eval::ctx_t> ctx)
  {
    tvars {
      flume_status_t ret (FLUME_OK);
      int fd (-1), nfd (-1);
      str d;
      vec<str> path;
      ssize_t i, sz;
      int f, m;
      labelset_t tmp;
      int which (LABEL_S | LABEL_I);
      strbuf b;
    }


    // optimization: for FSs with the minimum label, we know for a fact
    // that the problem was not-found.
    if (_cfg.has_minimum_label ()) {
      ret = FLUME_ENOENT;
    } else if (!path_split (&path, NULL, file)) {
      ret = FLUME_EPATH;
    } else {
      
      sz = path.size ();
      for (i = -1; i < sz && ret == FLUME_OK; i++) {

	if (i >= 0) d = path[i];
	else d = jail2real ("/");

	b << "/" << d;

	if (i == sz - 1) {
	  f = flags;
	  m = mode;
	} else {
	  f = O_RDONLY;
	  m = 0;
	}
	twait { open_impl (fd, d, f, m, mkevent (ret, nfd)); }
	if (ret == FLUME_OK) {
	  assert (nfd >= 0);

	  twait { get_labels (nfd, i == -1, &tmp, which, mkevent (ret), d); }
	  if (ret == FLUME_OK && !(tmp <= *proc)) {
	    if (ctx) {
	      ctx->error ("In Fswalk, at path '", str (b),
			  "', expected file label ", tmp,
			  " to be less than the process's ", *proc);
	    }
	    ret = FLUME_EPERM;
	  }
	  if (fd >= 0) close (fd);
	  fd = nfd;
	}
      }
    }
    if (fd >= 0) close (fd);
    if (ret == FLUME_OK) ret = FLUME_EAGAIN;

    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::mkdir_in (int pfd, const str &file, int mode,
			const labelset_t *ls, flume_status_cb_t cb)
  {
    tvars {
      flume_status_t ret;
      int fd;
    }
    // Precondition: that we already have a lock open for the parent dir.
    twait { mkdir_impl (pfd, file, mode, mkevent (ret, fd)); }
    if (ret == FLUME_OK) {
      twait { set_labels (fd, ls, LABEL_ALL, mkevent (ret), file, pfd); }
    }
    if (fd >= 0) close (fd);
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::double_open (const str &d, const str &f, int *dfdp,
			   int *fdp, flume_status_cb_t cb)
  {
    tvars {
      flume_status_t ret;
      int fd (-1), dfd (-1);
    }
    twait { open (d, O_RDONLY, 0, mkevent (dfd)); }
    if (dfd < 0) {
      ret = FLUME_ENOENT;
    } else {
      twait { open_for_stat_impl (dfd, f, mkevent (ret, fd)); }
    }
    if (ret == FLUME_OK) { 
      *dfdp = dfd;
      *fdp = fd;
    } else {
      if (dfd) close (dfd);
      if (fd) close (fd);
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::creat_in (int pfd, const str &file, int flags, int mode,
			ptr<labelset_t> creat, open_cb_t cb)
  {
    tvars {
      flume_status_t ret;
      int fd (-1);
      bool file_existed;
    }
    // Precondition: that we already have a lock open for the parent dir.
    twait { 
      open_impl (pfd, file, flags, mode, mkevent (ret, fd), &file_existed); 
    }

    if (!file_existed && ret == FLUME_OK && fd >= 0) {

      // There is a slight chance that some other process can slip in
      // and try to open this file before we've acquired the lock
      // in set_labels, since we cannot create the file and acquire the 
      // lock atomically. However, that process will not succeed in 
      // opening the extended attributes for this file (since they 
      // haven't been set yet) and therefore the open will fail. This 
      // race won't leak any data, but might make for less-than-perfect 
      // semantics, resulting in sporadic file open failures.
      // 
      // Possible fixes include using freebsd'd flock'ing, locking parent
      // directories on regular file opens, and locking on the name
      // of this file.
      //
      // Need to provide "file" and "pfd" since we can't set the
      // the backing file for the new file via fd; needs to be done via
      // file name;  Need the parent dir since we need to fchdir back
      // there.
      twait { set_labels (fd, creat, LABEL_ALL, mkevent (ret), file, pfd); }
    }
    cb->trigger (ret, fd);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_open_creat (const file_arg_fs_t *arg, 
				 file_res_t *res, cbi cb)
  {
    tvars {
      flume_status_t stat;
      int fd (-1), pfd (-1);
      ptr<labelset_t> creat;
      ptr<t_lock_handle_t> plh;
      str file;
      int flags (arg->c_args.flags);
      int mode (arg->c_args.mode);
    }
    
    res->set_status (FLUME_ENOENT);
    twait { 
      prepare_create (arg, res, &file, &pfd, &plh, &creat, mkevent ());
    }

    if (res->status == FLUME_OK) {
      twait { 
	creat_in (pfd, file, flags, mode, creat, mkevent (stat, fd)); 
      }
      res->set_status (stat);
      if (stat == FLUME_OK) {
	res->set_status (FLUME_LABEL_OK);
	creat->to_xdr (res->label);
      }
    }
    // release the lock
    plh = NULL;
    if (pfd >= 0) close (pfd);
    if (res->status != FLUME_LABEL_OK && fd >= 0) close (fd);
    cb->trigger (fd);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::prepare_modify (const file_arg_fs_t *arg, str *filep, 
			      int *pfdp, ptr<t_lock_handle_t> *plhp,
			      flume_status_cb_t cb, 
			      int opts,
			      bool *in_root_p,
			      ptr<eval::ctx_t> ctx)
  {
    tvars {
      flume_status_t ret;
      str pd, file;
      int pfd;
      str p_in (arg->c_args.path);
      ptr<labelset_t> vrfy (arg->xls ? labelset_t::alloc (*arg->xls) : NULL);
      int flags (0);
      filterset_t fs (arg->filters);
      ptr<labelset_t> proc;
    }

    if (arg->proc_parent_dir) 
      proc = labelset_t::alloc (*arg->proc_parent_dir);
    else
      proc = labelset_t::alloc (arg->proc);
    
    if (_cfg._readonly) {
      ret = FLUME_EROFS;
    } else if (!parent_dir (p_in, &pd, &file)) {
      ret = FLUME_EPATH;
    } else {
      if (in_root_p) 
	*in_root_p = is_root (pd);

      if (is_root (pd) && _cfg._integrity_ns) {
	flags = ALL_WRITES_OK;
      }

      flags = flags | WRITING | READING | opts;

      twait { 
	open_and_check (pd, O_RDONLY, 0, proc, fs, mkevent (ret, pfd), 
			flags, vrfy, plhp, tame::lock_t::EXCLUSIVE, ctx);
      }
      if (ret == FLUME_OK && pfd >= 0) {
	*filep = file;
	*pfdp = pfd;
      } else if (pfd >= 0) {
	close (pfd);
	*pfdp = -1;
      }
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::prepare_create (const file_arg_fs_t *arg,
			      file_res_t *res,
			      str *filep, 
			      int *pfdp, 
			      ptr<t_lock_handle_t> *plhp,
			      ptr<labelset_t> *ls_creat,
			      cbv cb,
			      int opts)
  {
    tvars {
      flume_status_t stat (FLUME_OK);
      ptr<labelset_t> proc (labelset_t::alloc (arg->proc));
      ptr<labelset_t> creat;
      bool in_root;
      str file;
      ptr<eval::ctx_t> ctx (eval::ctx_t::alloc ());
    }

    res->set_status (FLUME_OK);

    twait { 
      prepare_modify (arg, &file, pfdp, plhp, mkevent (stat), 
		      opts | CREATE, &in_root, ctx);
    }
    if (ctx->perm_error ()) {
      assert (stat != FLUME_OK);
      ctx->to_xdr (res);
    }

    if (stat == FLUME_OK) {

      if (filep) 
	*filep = file;
      
      if (arg->xls) creat = labelset_t::alloc (*arg->xls);
      else          creat = proc->clone (LABEL_NO_O);

      if (!(*proc <= *creat)) {
	PERM_ERROR (res, 
		    "Proc's label (%s) must be <= that on the "
		    "created file (%s)", 
		    proc, creat);

      } else if (in_root && _cfg._integrity_ns) {
	
	if (!creat) {
	  PERM_ERROR (res, "LabelFS creation without specified label");
	} else if (!(opts & MKDIR)) {
	  PERM_ERROR (res, "Can only make directories on top level of "
		      "integrity FS");
	} else {
	  twait { check_filename (creat, file, res, mkevent ()); }
	}
      }
      *ls_creat = creat;
    }
    
    if (res->status == FLUME_OK && stat != FLUME_OK) {
      res->set_status (stat);
    }
    
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  ptr<const labelset_t> 
  base_srv_t::def_ls ()
  {
    if (!_def_ls) {
      _def_ls = _cfg._ls ? _cfg._ls : New refcounted<labelset_t> ();
    }
    return _def_ls;
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::check_filename (const labelset_t *ls, const str &filename,
			      file_res_t *res, cbv cb)
  {
    tvars {
      str filename_correct;
    }

    twait { _cfg.idd ()->labelset2str (ls, mkevent (filename_correct)); }
    if (!filename_correct) {
      res->set_status (FLUME_EPERSISTENCE);
    } else {
      if (filename != filename_correct) {
	strbuf b ("Expected filename '%s'; got '%s' instead",
		  filename_correct.cstr (), filename.cstr ());
	PERM_ERROR (res, str (b));
      } else {
	res->set_status (FLUME_OK);
      }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

};
  
