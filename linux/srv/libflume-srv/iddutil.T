// -*-c++-*-

#include "async.h"
#include "crypt.h"
#include "arpc.h"
#include "iddutil.h"
#include "flume_srv_const.h"
#include "flume_idd_prot.h"
#include "parseopt.h"
#include "rxx.h"
#include "handlemgr.h"
#include "asyncutil.h"
#include "flume_ev_debug.h"
#include "unixutil.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

extern int optind;
extern char *optarg;

static const char *
cache_hit_str (bool ch)
{
  return ch ? " [cached]" : "" ;
}

namespace idd {



  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::init_T (cbb cb)
  {
    tvars {
      bool ret (false);
    }
    twait { conn ()->connect (mkevent (ret)); }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  cached_server_handle_t::init_T (cbb cb)
  {
    tvars {
      bool ret (false);
    }
    twait { server_handle_t::init (mkevent (ret)); }
    if (ret) {
      conn ()->set_srvcb (wrap (this, &cached_server_handle_t::dispatch));
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  void
  cached_server_handle_t::dispatch (svccb *sbp)
  {
    assert (sbp);
    switch (sbp->proc ()) {
    case IDD_MEMBER_OF_CACHE_INVALIDATE:
      handle_invalidate (sbp);
      break;
    default:
      sbp->reject (PROC_UNAVAIL);
      break;
    }
  }

  //-----------------------------------------------------------------------

  void
  cached_server_handle_t::handle_invalidate (svccb *sbp)
  {
    x_handle_t *arg = sbp->Xtmpl getarg<x_handle_t> ();
    if (FLUMEDBG2(CACHE)) {
      str s = handle_t (*arg).to_str ();
      FLUMEDBG4(CACHE,CHATTER, "Cache invalidate for group: %s\n", s.cstr ());
    }
	     
    _member_of_cache.invalidate (*arg);
    sbp->replyref (NULL);
  }

  //-----------------------------------------------------------------------

  str
  cfg_t::usage ()
  {
    return "IDD [-C] [-h <hostname>] [-p <port>] [-f <sz>] [-t <sz>] "
      "[-m <sz>]  hostname:port";
  }

  //-----------------------------------------------------------------------

  bool
  cfg_t::from_argv (const vec<str> &in, str *errp)
  {
    int ch;
    argv_t a (in);
    strbuf err;
    bool ret = true;
    bool cspec = false;

    getopt_reset ();

    while ((ch = getopt (a.size (), a, "Cg:h:p:f:t:m:")) != -1) {
      switch (ch) {
      case 'C':
	_caching = true;
	break;
      case 'h':
	_hostname = optarg;
	break;
      case 'g':
	cspec = true;
	if (!convertint (optarg, &_gea_cache_size)) {
	  err << "\tinvalid GEA cache size: " << optarg << "\n";
	  ret = false;
	}
	break;
      case 'p':
	if (!convertint (optarg, &_port) || _port <= 0) {
	  err << "\tinvalid port specified: " << optarg << "\n";
	  ret = false;
	}
	break;
      case 'f':
	cspec = true;
	if (!convertint (optarg, &_frz_cache_size)) {
	  err << "\tinvalid frozen cache size: " << optarg << "\n";
	  ret = false;
	}
	break;
      case 't':
	cspec = true;
	if (!convertint (optarg, &_thw_cache_size)) {
	  err << "\tinvalid thawed cache size: " << optarg << "\n";
	  ret = false;
	}
	break;
      case 'm':
	cspec = true;
	if (!convertint (optarg, &_member_of_cache_size)) {
	  err << "\tinvalid member of cache size: " << optarg << "\n";
	  ret = false;
	}
	break;
      default:
	err.fmt ("\tinvalid option given: -%c\n", ch);
	ret = false;
	break;
      }
    }

    int isz = in.size ();
    if (optind == isz - 1) {
      if (_hostname) {
	err << "  hostname specified twice...\n";
	ret = false;
      }
      if (_port >= 0) {
	err << "  port specified twice....\n";
	ret = false;
      }
      if (ret && !parse_hn (in[optind], &_hostname, &_port)) {
	err << "  cannot parse hostname:port: " << in[optind] << "\n";
	ret = false;
      }
    } else if (optind != isz) {
      err << "\ttoo many arguments given to IDD configuration\n";
      ret = false;
    }

    if (!_hostname) {
      err << "  no hostname given\n";
      ret = false;
    }
    if (_port < 0) {
      _port = idd::default_port;
    }

    if (cspec && !_caching) {
      err << "\tcaching parameters specified but no -C given!\n";
      ret = false;
    }

    if (err.tosuio ()->resid ()) {
      *errp = err;
    }

    return ret;
  }

  //-----------------------------------------------------------------------

  bool
  cfg_t::from_str_simple (const str &s) 
  {
    return parse_hn (s, &_hostname, &_port);
  }
  
  //-----------------------------------------------------------------------

  str
  cfg_t::to_str () const 
  {
    vec<str> args;
    args.push_back (strbuf ("h=%s", _hostname.cstr ()));
    args.push_back (strbuf ("p=%d", _port));
    args.push_back (strbuf ("C=%d", _caching));
    args.push_back (strbuf ("f=%zd", _frz_cache_size));
    args.push_back (strbuf ("t=%zd", _thw_cache_size));
    args.push_back (strbuf ("m=%zd", _member_of_cache_size));
    return join ("&", args);
  }

  //-----------------------------------------------------------------------

  str
  cfg_t::debug_str () const 
  {
    strbuf b;
    b << _hostname << ":" << _port;
    return b;
  }

  //-----------------------------------------------------------------------

#define CONVERT(v,f) \
  if (!convertint (v, &f)) return false; \
  break ;

  bool
  cfg_t::from_str (const str &s)
  {
    static rxx x ("&");
    vec<str> args;
    split (&args, x, s);

    for (size_t i = 0; i < args.size (); i++) {
      if (args[i].len () < 3 || args[i][1] != '=') {
	return false;
      } else {
	const char *val = args[i] + 2;
	switch (args[i][0]) {

	case 'h':
	  _hostname = val;
	  break;
	case 'C':
	  {
	    int tmp;
	    if (!convertint (val, &tmp))  return false;
	    _caching = tmp;
	    break;
	  }
	  
	case 'p': CONVERT (val, _port);
	case 'f': CONVERT (val, _frz_cache_size);
	case 't': CONVERT (val, _thw_cache_size);
	case 'm': CONVERT (val, _member_of_cache_size);

	default: return false;
	}
      }
    }
    if (args.size () == 0) 
      return false;
    return true;
  }

#undef CONVERT

  //-----------------------------------------------------------------------

  server_handle_t *
  cfg_t::alloc ()
  {
    if (_caching) { return New cached_server_handle_t (*this); }
    else { return New server_handle_t (*this); }
  }

  //-----------------------------------------------------------------------
  
  tamed void
  cfg_t::alloc_and_start (server_handle_t **h, cbb cb)
  {
    tvars {
      bool ret (false);
    }
    *h = alloc ();
    twait { (*h)->init (mkevent (ret)); }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  helper_t *
  server_handle_t::conn () 
  {
    if (!_h) {
      _h = New helper_inet_t (flume_idd_prog_1, _cfg.hostname (), _cfg.port ());

    }
    return _h;
  }

  //-----------------------------------------------------------------------

  str
  server_handle_t::to_str () const
  {
    strbuf b;
    b << _cfg._hostname << ":" << _cfg._port;
    return b;
  }

  //-----------------------------------------------------------------------

  tamed void 
  server_handle_t::freeze_1 (const label_t *in, frozen_label_t *out, 
			     flume_status_cb_t cb)
  {
    tvars {
      clnt_stat e;
      flume_status_t st (FLUME_OK);
      x_label_t arg;
      freeze_label_res_t idd_res;
      bool cache_hit (false);
      frozen_label_t *tmp;
    }

    if (!conn ()) {
      st = FLUME_ENOTCONN;
      warn << "IDD not connected: failing to freeze label.\n";
    } else if (!in || in->is_empty ()) {
      *out = handle_t::frozen_empty ();
    } else if ((tmp = freeze_from_cache (in))) {
      *out = *tmp;
      cache_hit = true;
    } else {
      in->to_xdr (&arg);
      twait { 
	conn ()->call (IDD_FREEZE_LABEL, &arg, &idd_res, mkevent (e)); 
      }
      if (e) {
	warn << "RPC failure when connecting to IDD: " << e << "\n";
	st = FLUME_EIDD;
      } else if (idd_res.status != FLUME_OK) {
	st = idd_res.status;
      } else {
	*out = *idd_res.frozen;
	cache_freeze (in, *out);
      }
    }

    /*
     * debug reporting for the caching code
     */
    if (FLUMEDBG2(CACHE)) {
      str out_s;
      str in_s = label_t::label2str (in);

      if (st == FLUME_OK) {
	out_s = handle_t (*out).to_str ();
      } else {
	out_s = status2str (st);
      }
      flumedbg_warn (CHATTER, "Freeze%s: %s => %s\n",
		    cache_hit_str (cache_hit),
		    in_s.cstr (), 
		    out_s.cstr ());
    }

    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::freeze_2 (const labelset_t *in, frozen_labelset_t *out, 
			     flume_status_cb_t cb)
  {
    tvars {
      rcset_t<flume_status_t> e (3, FLUME_OK);
      int i (0);
      flume_status_t r;
    }

    twait {
      freeze (in->S (), &out->S, mkevent (e[i++]));
      freeze (in->I (), &out->I, mkevent (e[i++]));
      freeze (in->O (), &out->O, mkevent (e[i++]));
    }
    r = e.project  ();
    cb->trigger (r);
  }

  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::thaw_2 (const frozen_labelset_t *x, labelset_t *out, 
			   flume_status_cb_t cb)
  {
    tvars {
      ptr<label_t> S, I, O_tmp;
      ptr<capset_t> O;
      rcset_t<flume_status_t> e (3, FLUME_OK);
      flume_status_t st;
      int i (0);
    }

    twait {
      thaw (&x->S, &S, mkevent (e[i++]));
      thaw (&x->I, &I, mkevent (e[i++]));
      thaw (&x->O, &O_tmp, mkevent (e[i++]));
    }
    
    st = e.project ();

    if (st == FLUME_OK) {
      O = New refcounted<capset_t> (*O_tmp);
      out->set_all (S, I, O);
    }

    cb->trigger (st);
  }

  //-----------------------------------------------------------------------


  tamed void
  server_handle_t::labelset2str (const labelset_t *ls, cbs cb)
  {
    tvars {
      frozen_labelset_t fls;
      flume_status_t rc;
      str ret;
    }

    twait { freeze (ls, &fls, mkevent (rc)); }
    if (rc == FLUME_OK) {
      ret = labelset2str (fls);
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::str2labelset (str s, labelset_t *lsp, 
				 flume_status_cb_t ev)
  {
    tvars {
      bool rc;
      frozen_labelset_t fls;
      flume_status_t st;
    }

    if ((rc = str2labelset (s, &fls))) {
      twait { thaw (&fls, lsp, mkevent (st)); }
    } else {
      st = FLUME_INTEGRITY_NS_BAD_NAME;
    }
    ev->trigger (st);
  }

#define N_LAB 3

  //-----------------------------------------------------------------------

  str
  server_handle_t::labelset2str (const frozen_labelset_t &fls)
  {
    str sv[N_LAB];
    armor_type_t at = ARMOR_32_NIL;

    const char *sep = ".";

    sv[0] = handle_t (fls.I).to_str (at);
    sv[1] = handle_t (fls.S).to_str (at);
    sv[2] = handle_t (fls.O).to_str (at);

    if (fls.O == 0) {
      if (fls.S == 0) {
	if (fls.I == 0) {
	  return "0";
	} else {
	  return sv[0];
	}
      } else {
	strbuf b;
	b << sv[0] << sep << sv[1];
	return b;
      }
    }
    
    strbuf b;
    for (size_t i = 0; i < N_LAB; i++) {
      if (i > 0) b << sep;
      b << sv[i];
    }
    return b;
  }

  //-----------------------------------------------------------------------

  bool
  server_handle_t::str2labelset (const str &s, frozen_labelset_t *fls)
  {
    bool ret = false;
    fls->S = fls->I = fls->O = 0;

    if (s == "0") {
      ret = true;
    } else {
      static rxx sep ("\\.");
      vec<str> v;
      split (&v, sep, s);
      while (v.size () < N_LAB) {
	v.push_back ("");
      }
      handle_t h[N_LAB];
      ret = true;
      for (size_t i = 0; i < N_LAB; i++) {
	if (v[i].len () > 0 && !h[i].from_str (v[i]))
	  ret = false;
      }
      if (ret) {
	fls->I = h[0].value ();
	fls->S = h[1].value ();
	fls->O = h[2].value ();
      }
    }
    return ret;
  }

#undef N_LAB

  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::member_of_1 (const idd_member_of_arg_t &arg,
				idd_member_of_res_t *res,
				flume_status_cb_t cb)
  {
    tvars {
      clnt_stat e;
      flume_status_t st (FLUME_OK);
      bool cache_hit (false);
    }
    
    if (!conn ()) {
      st = FLUME_ENOTCONN;
      warn << "IDD not connected; failing MEMBER_OF query.\n";
    } else if (member_of_from_cache (arg, res)) {
      cache_hit = true;
    } else {
      twait { conn ()->call (IDD_MEMBER_OF, &arg, res, mkevent (e));}
      if (e) {
	warn << "IDD RPC error in MEMBER_OF: " << e << "\n";
	st = FLUME_ERPC;
      } else {
	cache_member_of (arg, *res);
      }
    }

    /*
     * debug reporting for the caching code
     */
    if (FLUMEDBG2(CACHE)) {
      strbuf b1, b2;
      str s1, s2;
      rpc_print (b1, arg);
      s1 = b1;

      if (st == FLUME_OK) {
	rpc_print (b2, *res);
	s2 = b2;
      } else {
	s2 = status2str (st);
      }
      flumedbg_warn (CHATTER, "member_of%s: %s => %s\n",
		    cache_hit_str (cache_hit),
		    s1.cstr (), 
		    s2.cstr ());
    }

    cb->trigger (st);
  }
  
  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::thaw_1 (const frozen_label_t *in, ptr<label_t> *out, 
			   flume_status_cb_t cb)
  {
    tvars {
      clnt_stat e;
      thaw_label_res_t rpc_res;
      flume_status_t st (FLUME_OK);
      ptr<label_t> p;
      bool cache_hit (false);
    }

    if (*in == handle_t::frozen_empty ()) {
      *out = New refcounted<label_t> ();
    } else if (!conn ()) {
      st = FLUME_ENOTCONN;
      warn << "IDD not connected; failing to thaw label.\n";
    } else if ((p = thaw_from_cache (*in))) {
      *out = p;
      cache_hit = true;
    } else {
      twait { conn ()->call (IDD_THAW_LABEL, in, &rpc_res, mkevent (e)); }
      if (e) {
	warn << "RPC failure when connecting to IDD: " << e << "\n";
	st = FLUME_EIDD;
      } else if (rpc_res.status != FLUME_OK) {
	st = rpc_res.status;
      } else {
	*out = New refcounted<label_t> (*rpc_res.thawed);
	cache_thaw (*in, *out);
      }
    }

    if (FLUMEDBG2(CACHE)) {
      str s1 = handle_t (*in).to_str ();
      str s2;
      if (st == FLUME_OK) {
	s2 = (*out)->to_str ();
      } else {
	s2 = status2str (st);
      }
      flumedbg_warn (CHATTER, "Thaw%s: %s => %s\n",
		    cache_hit_str (cache_hit), s1.cstr (), s2.cstr ());
    }
    
    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  frozen_label_t *
  cached_server_handle_t::freeze_from_cache (const label_t *in)
  {
    if (!in || in->is_empty ()) {
      return &_empty_frz;
    }
    str s = in->freeze ();
    return _frz[s];
  }

  //-----------------------------------------------------------------------

  ptr<label_t>
  cached_server_handle_t::thaw_from_cache (const frozen_label_t &in)
  {
    if (in == _empty_frz) {
      return _empty_thw;
    }
    ptr<label_t> *p = _thw[in];
    if (p) return *p;
    return NULL;
  }

  //-----------------------------------------------------------------------

  void
  cached_server_handle_t::cache_freeze (const label_t *t, 
					const frozen_label_t &f) 
  {
    if (t && !t->is_empty ()) {
      str s = t->freeze ();
      _frz.insert (s, f);
    }
  }

  //-----------------------------------------------------------------------

  void
  cached_server_handle_t::cache_thaw (const frozen_label_t &f, 
				      ptr<label_t> t)
  {
    if (f != _empty_frz) {
      _thw.insert (f, t);
    }
  }

  //-----------------------------------------------------------------------

  void 
  member_of_cache_t::insert (const idd_member_of_arg_t &arg,
			     const idd_member_of_res_t &res)
  {
    str k = xdr2str (arg);
    cache::insert_res_t ir = _lru.insert (k, res);
    if (ir == cache::INSERT_NEW) {
      ptr<vec<str> > *vpp = _keyh[arg.group];
      if (vpp) {
	(*vpp)->push_back (k);
      } else {
	ptr<vec<str> > vp = New refcounted<vec<str> > ();
	vp->push_back (k);
	_keyh.insert (arg.group, vp);
      }
    }
  }

  //-----------------------------------------------------------------------
  
  idd_member_of_res_t *
  member_of_cache_t::fetch (const idd_member_of_arg_t &arg)
  {
    return _lru[xdr2str (arg)];
  }
  
  //-----------------------------------------------------------------------

  void
  member_of_cache_t::invalidate (const x_handle_t &h)
  {
    ptr<vec<str> > *vpp = _keyh[h];
    if (vpp) {
      for (size_t i = 0; i < (*vpp)->size (); i++) {

	if (FLUMEDBG2(CACHE)) {
	  str k = (**vpp)[i];
	  idd_member_of_arg_t a;
	  str s1 = handle_t (h).to_str ();
	  str s2;
	  if (str2xdr (a, k)) {
	    strbuf b;
	    rpc_print (b, a);
	    s2 = b;
	  } else {
	    s2 = " [undecodable]";
	  }
	  flumedbg_warn (CHATTER, "Cache Invalidate: %s => %s\n", 
			s1.cstr (), s2.cstr ());
	}

	_lru.remove ((**vpp)[i]);
      }
    }
  }

  //-----------------------------------------------------------------------
  
  void 
  cached_server_handle_t::cache_member_of (const idd_member_of_arg_t &arg,
					   const idd_member_of_res_t &res)
  {
    _member_of_cache.insert (arg, res);

  }

  //-----------------------------------------------------------------------

  bool
  cached_server_handle_t::member_of_from_cache (const idd_member_of_arg_t 
						&arg, 
						idd_member_of_res_t *res)
  {
    idd_member_of_res_t *p = _member_of_cache[arg];
    if (p) {
      *res = *p;
      return true;
    }
    return false;
  }

  //-----------------------------------------------------------------------

  bool
  cached_server_handle_t::req_privs_from_cache (const req_privs_arg_t &arg,
						req_privs_res_t *res)
  {
    return ((*res = _req_privs_cache[arg]) == FLUME_OK);
  }

  //-----------------------------------------------------------------------

  void
  cached_server_handle_t::cache_req_privs (const make_login_arg_t &arg,
					   const priv_tok_t &tok)
  {
    _req_privs_cache.insert (arg, tok);

  }

  //-----------------------------------------------------------------------

  void
  cached_server_handle_t::req_privs_update (const req_privs_arg_t &arg,
					    const req_privs_res_t &res)
  {
    _req_privs_cache.update (arg, res);
  }

  //-----------------------------------------------------------------------

  static str
  req_privs_arg2str (const req_privs_arg_t &arg)
  {
    strbuf b;
    rpc_print (b, arg);
    return b;
  }

  //-----------------------------------------------------------------------

  tamed void 
  server_handle_t::req_privs (const req_privs_arg_t *arg_p, 
			      flume_status_cb_t cb)
  {
    tvars {
      req_privs_res_t res;
      clnt_stat err;
      bool cache_hit (false);
      bool did_trig (false);
      req_privs_arg_t arg (*arg_p);
      handle_t h (arg.handle);
    }
    
    if (!h.is_persistent ()) {
      res = FLUME_EPERSISTENCE;
    } else if (!h.is_capability ()) {
      res = FLUME_ECAPABILITY;
    } else {
      
      if (req_privs_from_cache (arg, &res)) {
	assert (res == FLUME_OK);
	cache_hit = true;
	cb->trigger (res);
	did_trig = true;
      }

      twait { conn ()->call (IDD_REQ_PRIVS, &arg, &res, mkevent (err)); }
      if (err) {
	warn << "handle_req_privs: err " << err << "\n";
	res = FLUME_ERPC;
      }
    }
    req_privs_update (arg, res);
    
    if (FLUMEDBG2(CACHE)) {
      str s1 = req_privs_arg2str (arg);
      str s2 = status2str (res);
      
      flumedbg_warn (CHATTER, "req_privs%s: %s => %s\n",
		    cache_hit_str (cache_hit),
		    s1.cstr (),
		    s2.cstr ());
    }

    if (!did_trig)
      cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  str
  cached_req_priv_t::to_str () const
  {
    return rpa2str (_priv);
  }

  //-----------------------------------------------------------------------

  cached_req_priv_t::cached_req_priv_t (const make_login_arg_t &arg, 
					const priv_tok_t &tok)
    : _creation (sfs_get_timenow ()), 
      _duration (arg.duration), 
      _fixed (arg.fixed),
      _timestamp (sfs_get_timenow ())
  {
    _priv.token = tok;
    _priv.handle = arg.handle;
  }

  //-----------------------------------------------------------------------

  bool
  cached_req_priv_t::is_expired () const
  {
    return ((_duration > 0) &&
	    ((_fixed && _creation + _duration < sfs_get_timenow ()) ||
	     (!_fixed && _timestamp + _duration < sfs_get_timenow ())));
  }

  //-----------------------------------------------------------------------

  void
  cached_req_priv_t::touch ()
  {
    _timestamp = sfs_get_timenow();
  }

  //-----------------------------------------------------------------------

  void
  req_privs_cache_t::insert (const make_login_arg_t &arg, 
			     const priv_tok_t &tok)
  {
    cached_req_priv_t c (arg, tok);
    str k = c.to_str ();
    _lru.remove (k);
    _lru.insert (k, c);
  }

  //-----------------------------------------------------------------------

  void
  req_privs_cache_t::update (const req_privs_arg_t &arg, 
			     const req_privs_res_t &res)
  {
    str k = rpa2str (arg);
    if (res == FLUME_OK) {
      cached_req_priv_t *c = _lru[k];
      if (c) {
	c->touch ();
      }
    }
  }

  //-----------------------------------------------------------------------

  req_privs_res_t
  req_privs_cache_t::fetch (const req_privs_arg_t &arg)
  {
    req_privs_res_t r;
    str k = rpa2str (arg);
    cached_req_priv_t *c = _lru[k];
    if (c) {
      if (c->is_expired ()) {
	r = FLUME_EEXPIRED;
      } else {
	r = FLUME_OK;
      }
    } else {
      r = FLUME_ENOENT;
    }
    return r;
  }

  //-----------------------------------------------------------------------

  str rpa2str (const req_privs_arg_t &arg) { return xdr2str (arg); }

  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::expand_gea (u_int64_t gea, flume_extattr_t *ea,
			       flume_status_cb_t cb)
  {
    tvars {
      clnt_stat err;
      flume_status_t st (FLUME_OK);
      lookup_gea_arg_t arg;
      lookup_gea_res_t res;
      bool cache_hit (false);
    }

    if (gea_from_cache (gea, ea)) {
      cache_hit = true;
      st = FLUME_OK;
    } else {
      arg = gea;
      twait { conn ()->call (IDD_LOOKUP_GEA, &arg, &res, mkevent (err)); }
      if (err) {
	warn << "RPC failure when connecting to IDD: " << err << "\n";
	st = FLUME_ERPC;
      } else if (res.status != FLUME_OK) {
	st = res.status;
      } else {
	*ea = *res.extattr;
	cache_gea (gea, *ea);
      }
    }

    if (FLUMEDBG2(CACHE)) {
      str s = status2str (st);
      flumedbg_warn (CHATTER, "expand_gea%s: %" PRIx64 " => %s\n", 
		    cache_hit_str (cache_hit), gea, s.cstr ());
    }

    cb->trigger (st);
  }

  //-----------------------------------------------------------------------
  
  tamed void
  server_handle_t::make_login (const idd_make_login_arg_t &arg,
			       flume_status_cb_t cb)
  {
    tvars {
      clnt_stat err;
      flume_status_t st (FLUME_OK);
    }

    twait { conn ()->call (IDD_MAKE_LOGIN, &arg, &st, mkevent (err)); }
    if (err) {
      warn << "RPC failure in MAKE_LOGIN: " << err << "\n";
      st = FLUME_ERPC;
    } else if (st == FLUME_OK) {
      cache_req_privs (arg.larg, arg.token);
    }
    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::new_gea (u_int64_t gea, const flume_extattr_t &ea,
			    flume_status_cb_t cb)
  {
    tvars {
      clnt_stat err;
      flume_status_t st (FLUME_OK);
      insert_gea_arg_t arg;
    }

    arg.hash = gea;
    arg.extattr = ea;

    cache_gea (gea, ea);

    twait { conn ()->call (IDD_INSERT_GEA, &arg, &st, mkevent (err)); }
    if (err) {
      warn << "RPC failure in INSERT_GEA: " << err << "\n";
      st = FLUME_ERPC;
    } 
    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  tamed void
  server_handle_t::insert (const handle_t &h, const str &n, 
			   flume_status_cb_t cb)
  {
    tvars {
      flume_status_t st;
      insert_handle_arg_t arg;
      clnt_stat err;
    }
    arg.handle = h.value ();
    arg.name = n;
    twait { conn ()->call (IDD_INSERT_HANDLE,  &arg, &st, mkevent (err)); }
    if (err) {
      warn << "RPC failure in INSERT_HANDLE: " << err << "\n";
      st = FLUME_ERPC;
    } 
    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  void
  cached_server_handle_t::cache_gea (u_int64_t gea, const flume_extattr_t &ea)
  {
    _gea_cache.insert (gea, ea);
  }

  //-----------------------------------------------------------------------

  bool
  cached_server_handle_t::gea_from_cache (u_int64_t gea, flume_extattr_t *ea)
  {
    flume_extattr_t *tmp = _gea_cache[gea];
    if (tmp) {
      *ea = *tmp;
      return true;
    }
    return false;
  }

  //-----------------------------------------------------------------------
  
};

//-----------------------------------------------------------------------
//-----------------------------------------------------------------------


bool
parse_hn (const str &in, str *host, int *port)
{
  static rxx host_port_rxx ("([.0-9A-Za-z_-]*)(:[0-9]+)?");
  if (!host_port_rxx.match (in))
    return false;
  str h = host_port_rxx[1];
  if (h && h.len () > 0 && h != "-")
    *host = h;
  str p = host_port_rxx[2];
  if (p && p.len () > 1) {
    const char *pc = p.cstr () + 1;
    p = pc;
    if (!convertint (p, port))
      return false;
  }
  return true;
}

