// -*-c++-*-
#ifndef _LIBFLUME_IDDUTIL_H_
#define _LIBFLUME_IDDUTIL_H_

#include "async.h"
#include "pslave.h"
#include "flume_srv_const.h"
#include "flume_ev_labels.h"
#include "flume_prot.h"
#include "tame.h"
#include "flume_idd_prot.h"
#include "cache.h"

namespace idd {

  class server_handle_t;

  //-----------------------------------------------------------------------

  class cfg_t {
  public:
    cfg_t () : _port (-1),
	       _caching (false),
	       _frz_cache_size (default_frz_cache_size),
	       _thw_cache_size (default_thw_cache_size),
	       _member_of_cache_size (default_member_of_cache_size),
	       _gea_cache_size (default_gea_cache_size) {}
    
    bool from_argv (const vec<str> &argv, str *err = NULL);
    bool from_str (const str &s);
    bool from_str_simple (const str &s);
    str to_str () const;
    str debug_str () const;

    // allocate a new server handle from this configuration....
    server_handle_t *alloc ();

    // print the usage summary for how to specify an IDD configuration
    // in a configuration file
    static str usage ();

    // do everything for starting an IDD
    void alloc_and_start (server_handle_t **h, cbb cb, CLOSURE);

    friend class server_handle_t;
    friend class cached_server_handle_t;

    str hostname () const { return _hostname; }
    int port () const { return _port; }

  private:
    str _hostname;
    int _port;
    
    bool _caching;

    ssize_t _frz_cache_size;
    ssize_t _thw_cache_size;
    ssize_t _member_of_cache_size;
    ssize_t _req_privs_cache_size;
    ssize_t _gea_cache_size;
  };

  //-----------------------------------------------------------------------

  class server_handle_t {
  public:
    server_handle_t (const cfg_t &cfg) : _cfg (cfg), _h (NULL) {}

    virtual ~server_handle_t () { if (_h) delete _h; }

    virtual void init (cbb cb) { init_T (cb); }

    str to_str () const;
    helper_t *conn () ;

    void labelset2str (const labelset_t *in, cbs cb, CLOSURE);
    str labelset2str (const frozen_labelset_t &fls);

    void str2labelset (str s, labelset_t *lsp, flume_status_cb_t cv, CLOSURE);
    bool str2labelset (const str &s, frozen_labelset_t *fls);

    void freeze (const label_t *in, frozen_label_t *out,
		 flume_status_cb_t cb) { freeze_1 (in, out, cb); }
    void freeze (const labelset_t *in, frozen_labelset_t *out,
		 flume_status_cb_t cb) { freeze_2 (in, out, cb); }
    void thaw (const frozen_label_t *in, ptr<label_t> *out,
	       flume_status_cb_t cb) { thaw_1 (in, out, cb); }
    void thaw (const frozen_labelset_t *x, labelset_t *out,
	       flume_status_cb_t cb) { thaw_2 (x, out, cb); }

    void make_login (const idd_make_login_arg_t &arg, flume_status_cb_t cb,
		     CLOSURE);

    void expand_gea (u_int64_t gea, flume_extattr_t *ea,
		     flume_status_cb_t cb, CLOSURE);

    void new_gea (u_int64_t gea, const flume_extattr_t &ea,
		  flume_status_cb_t cb, CLOSURE);

    void member_of (const idd_member_of_arg_t &arg,
		    idd_member_of_res_t *res,
		    flume_status_cb_t cb) { member_of_1 (arg, res, cb); }

    void req_privs (const req_privs_arg_t *arg, flume_status_cb_t cb, 
		    CLOSURE);

    void insert (const handle_t &h, const str &nm, flume_status_cb_t cb, 
		 CLOSURE);

    const cfg_t &cfg () const { return _cfg; }

  protected:
    virtual frozen_label_t *freeze_from_cache (const label_t *in) 
    { return NULL; }
    virtual ptr<label_t> thaw_from_cache (const frozen_label_t &in)
    { return NULL; }
    
    virtual void cache_freeze (const label_t *t, const frozen_label_t &f) {}
    virtual void cache_thaw (const frozen_label_t &f, ptr<label_t> t) {}

    virtual void cache_member_of (const idd_member_of_arg_t &arg,
				  const idd_member_of_res_t &res) {}
    virtual bool member_of_from_cache (const idd_member_of_arg_t &arg,
				       idd_member_of_res_t *res) 
    { return false;}

    virtual bool req_privs_from_cache (const req_privs_arg_t &arg,
				       req_privs_res_t *res) 
    { return false; }

    virtual void req_privs_update (const req_privs_arg_t &arg,
				   const req_privs_res_t &res) {}
    
    virtual void cache_req_privs (const make_login_arg_t &arg,
				  const priv_tok_t &tok) {}

    virtual void cache_gea (u_int64_t gea, const flume_extattr_t &ea) {}

    virtual bool gea_from_cache (u_int64_t gea, flume_extattr_t *ea)
    { return false; }

  private:
    void init_T (cbb cb, CLOSURE);

    void member_of_1 (const idd_member_of_arg_t &arg,
		      idd_member_of_res_t *res,
		      flume_status_cb_t cb, CLOSURE);

    void freeze_1 (const label_t *in, frozen_label_t *out,
		   flume_status_cb_t cb, CLOSURE);
    void freeze_2 (const labelset_t *in, frozen_labelset_t *out,
		   flume_status_cb_t cb, CLOSURE);
    void thaw_1 (const frozen_label_t *in, ptr<label_t> *out,
	       flume_status_cb_t cb, CLOSURE);
    void thaw_2 (const frozen_labelset_t *x, labelset_t *out,
		 flume_status_cb_t cb, CLOSURE);

  protected:
    cfg_t _cfg;
    helper_inet_t *_h;
  };

  //-----------------------------------------------------------------------

  class member_of_cache_t {
  public:
    member_of_cache_t (ssize_t s) : _lru (s) {}
    
    void insert (const idd_member_of_arg_t &arg,
		 const idd_member_of_res_t &res);

    idd_member_of_res_t *fetch (const idd_member_of_arg_t &arg);

    idd_member_of_res_t *operator[] (const idd_member_of_arg_t &arg)
    { return fetch (arg); }

    void invalidate (const x_handle_t &h);
    void init (cbb cb) { init_T (cb); }

  protected:
    void init_T (cbb cb, CLOSURE);
  private:
    cache::lru_t<str,idd_member_of_res_t> _lru;
    qhash<x_handle_t, ptr<vec<str> > > _keyh;
  };

  //-----------------------------------------------------------------------

  str rpa2str (const req_privs_arg_t &arg);

  class cached_req_priv_t {
  public:
    cached_req_priv_t (const make_login_arg_t &p, const priv_tok_t &tok);
    str to_str () const;
    bool is_expired () const;
    void touch ();
  private:
    req_privs_arg_t _priv;
    const time_t _creation, _duration;
    const bool _fixed;
    time_t _timestamp;
  };

  //-----------------------------------------------------------------------

  class req_privs_cache_t {
  public:
    req_privs_cache_t (ssize_t s) : _lru (s) {}

    void insert (const make_login_arg_t &p, const priv_tok_t &tok);
    void update (const req_privs_arg_t &arg, const req_privs_res_t &res);
    req_privs_res_t fetch (const req_privs_arg_t &arg);
    req_privs_res_t operator[] (const req_privs_arg_t &arg)
    { return fetch (arg); }
  private:
    cache::lru_t<str, cached_req_priv_t> _lru;
  };


  //-----------------------------------------------------------------------

  class cached_server_handle_t : public server_handle_t {
  public:
    
    cached_server_handle_t (const cfg_t &cfg)
      : server_handle_t (cfg),
	_frz (cfg._frz_cache_size),
	_thw (cfg._thw_cache_size),
	_gea_cache (cfg._gea_cache_size),
	_member_of_cache (cfg._member_of_cache_size),
	_req_privs_cache (cfg._req_privs_cache_size),
	_empty_frz (handle_t::frozen_empty ()),
	_empty_thw (New refcounted<label_t>  ()) {}

    cached_server_handle_t (const cached_server_handle_t &h)
      : server_handle_t (h._cfg),
	_frz (h._cfg._frz_cache_size),
	_thw (h._cfg._thw_cache_size),
	_gea_cache (h._cfg._gea_cache_size),
	_member_of_cache (_cfg._member_of_cache_size),
	_req_privs_cache (_cfg._req_privs_cache_size),
	_empty_frz (handle_t::frozen_empty ().value ()),
	_empty_thw (New refcounted<label_t> ()) {}

    virtual ~cached_server_handle_t () {}
	
  protected:

    void dispatch (svccb *sbp);
    void handle_invalidate (svccb *sbp);

    frozen_label_t *freeze_from_cache (const label_t *in) ;
    ptr<label_t> thaw_from_cache (const frozen_label_t &in) ;
    void cache_freeze (const label_t *t, const frozen_label_t &f);
    void cache_thaw (const frozen_label_t &f, ptr<label_t> t);

    void cache_member_of (const idd_member_of_arg_t &arg,
			  const idd_member_of_res_t &res);
    bool member_of_from_cache (const idd_member_of_arg_t &arg,
			       idd_member_of_res_t *res) ;

    void cache_gea (u_int64_t gea, const flume_extattr_t &ea);
    bool gea_from_cache (u_int64_t gea, flume_extattr_t *ea);
    
    bool req_privs_from_cache (const req_privs_arg_t &arg, 
			       req_privs_res_t *res) ;
    void req_privs_update (const req_privs_arg_t &arg,
			   const req_privs_res_t &res);
    void cache_req_privs (const make_login_arg_t &arg,
			  const priv_tok_t &tok);

    void init (cbb cb) { init_T (cb); }
  private:
    void init_T (cbb cb, CLOSURE);
    cache::lru_t<str, frozen_label_t> _frz;
    cache::lru_t<frozen_label_t, ptr<label_t> > _thw;
    cache::lru_t<u_int64_t, flume_extattr_t> _gea_cache;
    member_of_cache_t _member_of_cache;
    req_privs_cache_t _req_privs_cache;
    frozen_label_t _empty_frz;
    ptr<label_t> _empty_thw;
    ptr<asrv> _srv;
  };

  //-----------------------------------------------------------------------
};

bool parse_hn (const str &in, str *h, int *p);

#endif /* _LIBFLUME_IDDUTIL_H_ */
