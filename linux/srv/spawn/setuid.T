

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

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

extern char **environ;

namespace flmspwn { 

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::get_label_1 (label_type_t typ, x_label_t *out,
			  file_res_t *res, cbv cb)
  { 
    tvars {
      get_label_arg_t gla;
      get_label_res_t glr;
      clnt_stat err;
    }
    gla.type = typ;
    gla.specifiers = LABEL_SCOPE_PROCESS;
    twait { _cli->call (GET_LABEL, &gla, &glr, mkevent (err)); }
    if (err) {
      warn << "RPC error in GET_LABEL: " << err << "\n";
      res->set_status (FLUME_ERPC);
      *res->error = int (err);
    } else if (glr.status != FLUME_OK) {
      res->set_status (glr.status);
    } else {
      res->set_status (FLUME_OK);
      *out = *glr.label;
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------
  
  tamed void
  spawner_t::get_label_2 (label_type_t typ, ptr<label_t> *out, 
			  file_res_t *res, cbv cb)
  {
    tvars {
      x_label_t tmp;
    }
    twait { get_label_1 (typ, &tmp, res, mkevent ()); }
    if (res->status == FLUME_OK) {
      *out = New refcounted<label_t> (tmp);
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::set_label (label_type_t typ, ptr<const label_t> in,
			file_res_t *res, const char *desc, cbv cb)
  {
    tvars {
      set_label_arg_t sla;
      flume_res_t slr;
      clnt_stat err;
    }
    sla.which.type = typ;
    sla.which.specifiers.set_scope (LABEL_SCOPE_PROCESS);
    in->to_xdr (&sla.new_label);
    twait { _cli->call (SET_LABEL, &sla, &slr, mkevent (err)); }
    if (err) {
      warn << "RPC error in SET_LABEL: " << err << "\n";
      res->set_status (FLUME_ERPC);
      *res->error = int (err);
    } else if (slr.status == FLUME_EPERM) {
      res->set_status (slr.status);
      *res->eperm = *slr.eperm;
    } else {
      res->set_status (slr.status);
    } 
    cb->trigger ();
  }

  //-----------------------------------------------------------------------
  
  tamed void
  spawner_t::raise_S (const handle_t &h, ptr<label_t> *old_S,
		      file_res_t *res, cbv cb)
  {
    tvars {
      ptr<label_t> S;
    }
    twait { get_label_2 (LABEL_S, old_S, res, mkevent ()); }
    if (res->status == FLUME_OK) {
      S = New refcounted<label_t> (**old_S);
      S->insert (h);
      twait { set_label (LABEL_S, S, res, "raise S label", mkevent ()); }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::do_setuid (const spawn_i_arg_t &arg, str *cmd,
			vec<str> *argv, file_res_t *res, cbv cb)
  {
    tvars {
      str file (arg.c_args.cmd);
      setuid_file_t sf (file);
      int fd (-1);
      ptr<label_t> O;
      ptr<label_t> old_S;
      ptr<handle_t> h (New refcounted<handle_t> (arg.setuid_h));
      ptr<label_t> new_I;
    }

    twait { raise_S (*h, &old_S, res, mkevent ()); }
    if (res->status == FLUME_OK) {
      twait { open (file, res, mkevent (fd)); }
      if (res->status != FLUME_PATH_OK) {
	/* noop */
      } else {
	_open_fds.insert (fd, false, false, 
			  strbuf ("[%" PRIx64 "] setuid file", 
				  getflmpid ().value ()));
	assert (fd >= 0);
	sf.read (fd, res);
	if (res->status != FLUME_OK) {
	  /* noop */
	} else if (!sf.verify ()) {
	  warn ("Setuid file '%s' is missing required fields\n", file.cstr ());
	  res->set_status (FLUME_EINVAL);
	} else {
	  res->set_status (FLUME_OK);

	  twait { setuid_login (*sf._h, sf._token, res, mkevent ()); }

	  if (res->status == FLUME_OK) {
	    if (sf._I_frozen) {
	      twait { set_I_label (*sf._I_frozen, res, mkevent (), &new_I); }
	    }
	  }

	  // Use might have asked that the new process run at least
	  // at the given integrity level.
	  if (res->status == FLUME_OK) {
	    verify_I_label (arg.I_min, new_I, res);
	  }

	  if (res->status == FLUME_OK) {
	    twait { 
	      set_label (LABEL_S, old_S, res, "restore S label", mkevent ()); 
	    }
	    if (res->status == FLUME_OK) {
	      twait { get_label_2 (LABEL_O, &O, res, mkevent ()); }
	      if (res->status == FLUME_OK) {
		O->remove (capability_t (CAPABILITY_ADD, *h));
		O->remove (capability_t (CAPABILITY_SUBTRACT, *h));
		twait { set_label (LABEL_O, O, res, "O label", mkevent ()); }
		if (res->status == FLUME_OK) {
		  *cmd = sf._argv[0];
		  *argv = sf._argv;
		}
	      }
	    }
	  }
	}
      }
    }
    if (fd >= 0) {
      _open_fds.close (fd);
    }
    cb->trigger ();
  }
  
  //-----------------------------------------------------------------------

  tamed void
  spawner_t::setuid_login (handle_t h, const str &tok, file_res_t *res, cbv cb)
  {
    tvars {
      req_privs_arg_t rpa;
      req_privs_res_t rpr;
      clnt_stat err;
    }

    h.to_xdr (&rpa.handle);
    rpa.token.set_typ (PRIV_TOK_STR);
    *rpa.token.strtok = tok;

    twait { _cli->call (REQ_PRIVS, &rpa, &rpr, mkevent (err)); }
    if (err) {
      warn << "RPC error in REQ_PRIVS: " << err << "\n";
      res->set_status (FLUME_ERPC);
      *res->error = int (err);
    } else if (rpr != FLUME_OK) {
      res->set_status (rpr);
      if (rpr == FLUME_EPERM) {
	res->eperm->desc = "Failed in REQ_PRIVs to get privileges";
      }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  spawner_t::set_I_label (const handle_t &fl, file_res_t *res, cbv cb,
			  ptr<label_t> *new_I_p)
  {
    tvars {
      thaw_label_res_t tlr;
      x_label_t old_I;
      clnt_stat err;
      ptr<label_t> new_I;
    }
    twait { _cli->call (FLUME_THAW_LABEL, &fl, &tlr, mkevent (err)); }
    if (err) {
      warn << "RPC error in THAW_LABEL: " << err << "\n";
      res->set_status (FLUME_ERPC);
      *res->error = int (err);
    } else if (tlr.status != FLUME_OK) {
      res->set_status (tlr.status);
    } else {
      new_I = New refcounted<label_t> (*tlr.thawed);
      twait { get_label_1 (LABEL_I, &old_I, res, mkevent ()); }
      if (res->status == FLUME_OK) {
	new_I->union_in (old_I);
	*new_I_p = new_I;
	twait { set_label (LABEL_I, new_I, res, "I label", mkevent ()); }
      }
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  static void str2h (const str &s, ptr<handle_t> *out)
  {
    handle_t h;
    if (h.from_str (s)) {
      *out = New refcounted<handle_t> (h);
    }
  }

  //-----------------------------------------------------------------------

  bool
  setuid_file_t::verify () const
  {
    return (_argv.size () && _h && _token);
  }

  //-----------------------------------------------------------------------

#define BUFSZ 1024
  void
  setuid_file_t::read (int fd, file_res_t *res)
  {
    char buf[BUFSZ];
    char *bp;
    FILE *file;
    static rxx x ("\\s+");
    vec<str> v;

    if (!(file = fdopen (fd, "r"))) {
      warn ("Error fdopen'ing setuid file '%s': %m\n", _path.cstr ());
      res->set_status (FLUME_EIO);
    } else {

      while ((bp = fgets (buf, BUFSZ, file))) {
	v.setsize (0);
	split (&v, x, buf);
	if (v.size () > 1) {
	  if (v[0] == "Handle" || v[0] == "Tag") {
	    str2h (v[1], &_h);
	  } else if (v[0] == "Token") {
	    _token = v[1];
	  } else if (v[0] == "IntegrityLabel") {
	    str2h (v[1], &_I_frozen);
	  } else if (v[0] == "Argv") {
	    v.pop_front ();
	    _argv = v;
	  }
	}
      }
      if (ferror (file)) {
	warn ("Error when readiing file '%s': %m\n", _path.cstr ());
	res->set_status (FLUME_EIO);
      } else {
	res->set_status (FLUME_OK);
      }
    }
  }
#undef BUFSZ

  //-----------------------------------------------------------------------

  void
  spawner_t::verify_I_label (const x_label_t *I_min_x, 
			     ptr<const label_t> new_I,
			     file_res_t *res)
  {
    if (I_min_x) {
      label_t I_min (*I_min_x);
      
      if (!I_min.is_empty ()) {
      
	if (!new_I) new_I = New refcounted<label_t> ();

	if (!(I_min.subset_of (new_I))) {
	  ptr<eval::ctx_t> ctx (eval::ctx_t::alloc ());
	  ctx->error ("Wanted an integrity label of at least ", I_min,
		      "but new process is running with integrity ", *new_I);
	  ctx->to_xdr (res);
	}
      }
    }
  }


  //-----------------------------------------------------------------------


};
