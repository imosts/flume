
// -*-c++-*-
#include "fs.h"
#include "flume_fs_prot.h"
#include "tame_autocb.h"
#include "parseopt.h"

namespace fs { 

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::handle_read_filter (svccb *sbp)
  {
    tvars {
      file_arg_fs_t *arg (sbp->Xtmpl getarg<file_arg_fs_t> ());
      file_arg_fs_t narg;
      file_res_t res;
      int fd;
      ptr<eval::ctx_t> ctx (eval::ctx_t::alloc ());
    }
    
    narg = *arg;
    
    // XXX kludge to get us to declassify relative to the setuid
    // handle;
    {
      label_t l (arg->proc.S);
      if (arg->setuid_h) {
	handle_t h (*arg->setuid_h);
	l.insert (h);
	l.to_xdr (&narg.proc.S);
      }
    }
    

    twait { handle_open_existing (&narg, &res, mkevent (fd), -1, ctx); }
    if (res.status == FLUME_LABEL_OK) {
      twait { read_filter (narg.c_args.path, fd, &res, mkevent ()); }
      close (fd);
    } else if (res.status == FLUME_EPERM) {
      ctx->to_xdr (&res);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::label_from_fstr (const str &fstr, label_t *l, flume_status_t *st,
			       cbv cb)
  {
    tvars {
      handle_t h;
      ptr<label_t> tmp;
      flume_status_t sttmp;
      frozen_label_t fl;
    }
    if (!h.from_str (fstr)) {
      *st = FLUME_EHANDLE;
    } else {
      fl = h;
      twait { thaw_label (&fl, &tmp, &sttmp, mkevent ()); }
      if (sttmp == FLUME_OK && tmp) {
	*l = *tmp;
      }
      *st = sttmp;
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  base_srv_t::read_filter (const str &fn, int fd, file_res_t *res, cbv cb)
  {
    tvars {
      conftab ct;
      str find, replace, handle, token;
      flume_status_t st;
      handle_t h;
      filter_t f;
    }

    assert (fd >= 0);
    
    ct.add ("Find", &find)
      .add ("Replace", &replace)
      .add ("Handle", &handle)
      .add ("Token", &token);
    
    if (!ct.run (fn, 0, fd) || !(find && replace && handle && token)) {
      st = FLUME_EIO;
    } else if (!h.from_str (handle)) {
      st = FLUME_EHANDLE;
    } else {
      twait {
	label_from_fstr (find, f.find (), &st, mkevent ());
	label_from_fstr (replace, f.replace (), &st, mkevent ());
      }
      if (st == FLUME_OK) {
	res->set_status (FLUME_FILTER_OK);
	f.to_xdr (&res->filter->filter);

	res->filter->req_privs.alloc ();
	req_privs_arg_t a;
	a.handle = h;
	a.token.set_typ (PRIV_TOK_STR);
	*a.token.strtok = token;
	*res->filter->req_privs = a;
      } 
    }

    if (st != FLUME_OK)
      res->set_status (st);

    cb->trigger ();
  }

  //-----------------------------------------------------------------------

};
  
