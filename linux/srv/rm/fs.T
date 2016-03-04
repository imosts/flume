
// -*-c++-*-

#include "rm.h"
#include "tame.h"
#include "mounttree2.h"
#include "flume_fs_prot.h"

namespace rm {

  //-----------------------------------------------------------------------

  void
  fs_t::cli_t::caught_sig (int status)
  {
    warn << name () << " exited with status=" << status << "\n";

    _x = NULL;
    _cli = NULL;
    _pid = -1;
  }

  //-----------------------------------------------------------------------

  ptr<mounttree2::iterator_t<fs_t> > 
  rm_t::mk_iterator (const str &cwd, const str &in, str *out, vec<str> *v)
  {
    str p;
    ptr<mounttree2::iterator_t<fs_t> > it;

    if (!(p = fs::combine_and_normalize (cwd, in, v)) || 
	p.len () == 0 || 
	p[0] != '/' || 
	!(it = _tree.mk_iterator (*v)) || 
	!it->ok ()) {
      return NULL;
    }

    if (out) *out = p;

    return it;
  }

  //-----------------------------------------------------------------------
  /**
   * 
   */
  tamed void
  rm_t::fsop (int proc, const str &cwd, const file_arg_t *a, 
	      ptr<const labelset_t> ls, int opts, file_res_t *res, cbv cb, 
	      const filterset_t *filt, str *p_norm_p, str *unjailed_p,
	      ptr<const labelset_t> ls_proc_creat)
  {
    tvars {
      ptr<mounttree2::iterator_t<fs_t> > it;
      str m, f, f2;
      ptr<fs_t> fs;
      file_arg_fs_t fsarg;
      vec<str> path1, path_src;
      flume_status_t status (FLUME_OK);
    }

    if (!(it = mk_iterator (cwd, a->c_args.path, p_norm_p, &path1))) {

      status = FLUME_EPATH;

    } else if ((opts & FS_OP_PAIRWISE) && !a->c_args.path_src) {
      
      status = FLUME_EINVAL;

    } else if ((opts & (FS_OP_PAIRWISE|FS_OP_SAMEDIR)) == 
	       (FS_OP_PAIRWISE|FS_OP_SAMEDIR) &&
	       (!fs::combine_and_normalize (cwd, *a->c_args.path_src, 
					    &path_src) ||
		!fs::in_same_dir (path1, path_src) ||
		path_src.size () == 0 ||
		!(f2 = path_src.back ())
		)) {
      
      status  = FLUME_EXDEV;

    } else {

      fsarg.c_args = a->c_args;
      fsarg.cwd = 0;
      fsarg.options = opts;
      if (filt)
	filt->to_xdr (&fsarg.filters);


      if (_setuid_h) {
	fsarg.setuid_h.alloc ();
	_setuid_h->to_xdr (fsarg.setuid_h);
      }

      if (ls_proc_creat) {
	fsarg.proc_parent_dir.alloc ();
	ls_proc_creat->to_xdr (fsarg.proc_parent_dir);
      }

      ls->to_xdr (&fsarg.proc);

      if (f2) 
	*fsarg.c_args.path_src =  f2;
      
      /* xls = Extra Label Set; In the case of Creation, we'll apply this
       * the created file; in the case of opening, it will serve as a 
       * "verify" label
       */
      if (a->xls) {
	labelset_t xls (*a->xls);
	if (!xls.is_persistent ()) {
	  status = FLUME_EPERSISTENCE;
	} else {
	  fsarg.xls.alloc ();
	  *fsarg.xls= *a->xls;
	}
      }
    }

    if (status == FLUME_OK) {

      res->set_status (FLUME_ENOENT);
      while ((fs = it->next (&m, &f)) && !is_ok_res (*res)) {

	if (!(opts & FS_OP_WRITE) || !fs->is_readonly ()) {
	  fsarg.c_args.path = f;
	  if (unjailed_p) {
	    *unjailed_p = fs::paste (fs->root (), f);
	  }

	  twait { fs->op (proc, &fsarg, opts, res, mkevent ()); }

	  if (FLUMEDBG2(FS)) {
	    str tmp = rpc_enum_to_str (res->status);
	    flumedbg_warn (CHATTER,
			  "Iterating over FS: %s + %s => %s\n",
			   m.cstr (), f.cstr (), tmp.cstr ());
	  }
	}
      }


    } else {
      res->set_status (status);
    }
      
    cb->trigger ();
  }

  //-----------------------------------------------------------------------
  
  fs_t::cli_t *
  fs_t::pick_cli ()
  {
    fs_t::cli_t *ret = NULL;
    for (size_t i = 0; i < _cfg._n_proc; i++) {
      if ((ret = next_cli ()))
	return ret;
    }
    return NULL;
  }

  //-----------------------------------------------------------------------

  fs_t::cli_t *
  fs_t::next_cli ()
  {
    // XXX Round robin
    assert (_nxt_cli < _cfg._n_proc);
    fs_t::cli_t *ret = &_cli[_nxt_cli];
    _nxt_cli = (_nxt_cli + 1) % _cfg._n_proc;
    return ret;
  }

  //-----------------------------------------------------------------------

  tamed void
  fs_optmz_t::op_T (int proc, const file_arg_fs_t *a, int opts, file_res_t *r,
		    cbv cb)
  {
    tvars {
      bool handled (false);
    }

    if (_cfg.has_minimum_label ()) {
      switch (proc) {
      case FLUME_FS_OPEN:
	handled = open (a, opts, r);
	break;
      case FLUME_FS_STAT:
	handled = stat (a, opts, r);
	break;
      default:
	break;
      }
    }

    if (!handled) {
      twait { fs_t::op (proc, a, opts, r, mkevent()); }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  str
  fs_optmz_t::mkfile (const file_arg_fs_t *a)
  {
    strbuf b;
    b << _cfg._root << "/" << a->c_args.path;
    return b;
  }

  //-----------------------------------------------------------------------
  
  bool
  fs_optmz_t::stat (const file_arg_fs_t *a, int opts, file_res_t *r)
  {
    str s = mkfile (a);
    struct stat sb;
    int rc = ::stat (s.cstr(), &sb);
    if (rc < 0) {
      r->set_status (fs::errno2err ());
    } else {
      r->set_status (FLUME_STAT_OK);
      fs::stat2xdr (sb, r->stat);
    }
    return true;
  }

  //-----------------------------------------------------------------------

  bool
  fs_optmz_t::open (const file_arg_fs_t *a, int opts, file_res_t *r)
  {
    bool ret = false;
    if (a->c_args.mode == O_RDONLY) {
      str s = mkfile (a);
      int fd = ::open (s.cstr (), a->c_args.mode);
      if (fd < 0) {
	r->set_status (fs::errno2err ());
      } else {
	r->set_status (FLUME_FDPASS_OK);
	r->fdpass_ok->fd = fd;
	_cfg.def_ls ()->to_xdr (&r->fdpass_ok->label);
      }
      ret = true;
    }
    return ret;
  }

  //-----------------------------------------------------------------------

  tamed void
  fs_t::op_T (int proc, const file_arg_fs_t *a, int opts, file_res_t *r, 
	      cbv cb)
  {
    tvars {
      int fd (-1);
      clnt_stat err;
      time_t *ts (NULL);
      str path (a->c_args.path);
      fs_t::cli_t *cli;
    }

    cli = pick_cli ();

    if (!cli) {
      r->set_status (FLUME_ENOTCONN);

    } else if (proc == FLUME_FS_OPEN && 
	       _cfg._miss_cache_lifetime &&
	       _cfg.has_minimum_label () && 
	       path &&
	       (ts = _miss_cache[path]) &&
	       (sfs_get_timenow() - *ts < _cfg._miss_cache_lifetime)) {
      
      r->set_status (FLUME_ENOENT);
      
    } else {
      
      if (ts) {
	_miss_cache.remove (a->c_args.path);
      }

      
      twait { cli->cli()->call (proc, a, r, mkevent (err)); }

      if (err) {
	warn << "RPC error in proc " << proc << " for " << cli->name ()
	     << ": " << err << "\n";
	r->set_status (FLUME_ERPC);
	*r->error = int (err);
	
      } else if (proc == FLUME_FS_OPEN &&
		 r->status == FLUME_ENOENT &&
		 _cfg.has_minimum_label ()) {

	_miss_cache.insert (path, sfs_get_timenow());

      } else if (r->status == FLUME_PATH_OK && (opts & FS_OP_GETPATH)) {
	/* noop */

      } else if (r->status == FLUME_STAT_OK && (opts & FS_OP_GETSTAT)) {
	/* noop */

      } else if (r->status == FLUME_LABEL_OK && (opts & FS_OP_GETLABEL)) {

	/* noop */

      } else if (r->status == FLUME_LABEL_OK && (opts & FS_OP_FDPASS)) {
	fd = cli->x()->recvfd ();
	if (fd < 0) {
	  warn << "Unexpected FD received for proc " << proc << "\n";
	  r->set_status (FLUME_EINVAL); 
	} else {
	  x_labelset_t x = *r->label;
	  r->set_status (FLUME_FDPASS_OK);
	  r->fdpass_ok->fd = fd;
	  r->fdpass_ok->label = x;
	}

      } else if (r->status == FLUME_OK) {
	
	/* noop */
	
      } else {
	// No need for error reporting, since many of these errors
	// are either permission denied on noent errors.
	// warn << "Error in FS, proc " << proc << ": " << r->status << "\n";
      }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  void
  fs_t::cli_t::init (fs_t *f, size_t i)
  {
    _fs = f;
    _id = i;
    _name = dbg_name ();
  }

  //-----------------------------------------------------------------------

  str
  fs_t::cli_t::dbg_name () const
  {
    strbuf b;
    b << "Child FS (pid=" << _pid <<"; prog=" << _fs->_cfg._prog 
      << "; root=" << _fs->_cfg._root << "; " 
      << "mount=" << _fs->_cfg._mountpoint 
      << "; id=" << _id << ")";
    return b;

  }

};
