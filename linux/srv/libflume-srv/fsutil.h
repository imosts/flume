
// -*-c++-*-
#ifndef _LIBFLUME_FSUTIL_H_
#define _LIBFLUME_FSUTIL_H_

#include "async.h"
#include "arpc.h"
#include "flume_prot.h"
#include "flume_ev_labels.h"
#include "flume_srv_const.h"
#include "unixutil.h"
#include "tame.h"
#include "flume_fs_prot.h"
#include "iddutil.h"
#include "flume_idd_prot.h"
#include "flume_cfg.h"


namespace fs {

  class gea_t {
  public:
    static u_int64_t to_b60 (const flume_extattr_t &t);
    static u_int32_t mask_bits (u_int64_t in);
    static void b60_to_uid_gid (u_int64_t bits, uid_t *uid, gid_t *gid);
    static u_int64_t unmask_bits (u_int32_t x);
    static u_int64_t uid_gid_to_b60 (uid_t uid, gid_t gid);
  };

  // an interface to extended attributes on the file system
  class ea_mgr_t {
  public:
    ea_mgr_t () {}
    virtual ~ea_mgr_t () {}

    virtual void setlabelset_impl (int fd, const str &fn, 
				   const frozen_labelset_t &in, 
				   flume_status_cb_t cb) = 0;

    virtual void getlabelset_impl (int fd, const str &fn, 
				   frozen_labelset_t *in, 
				   flume_status_cb_t cb) = 0;

    void setlabelset (int fd, const frozen_labelset_t &in, 
		      flume_status_cb_t cb);
    void setlabelset (const str &fn, const frozen_labelset_t &in, 
		      flume_status_cb_t cb);
    void getlabelset (const str &fn, frozen_labelset_t *in, 
		      flume_status_cb_t cb);
    void getlabelset (int fd, frozen_labelset_t *in, 
		      flume_status_cb_t cb);

    flume_status_t enable_attr (const str &fn, const str &af);
  };

  class real_ea_mgr_t : public ea_mgr_t {
  public:
    real_ea_mgr_t () : ea_mgr_t () {}

    void setlabelset_impl (int fd, const str &fn, 
			   const frozen_labelset_t &in, 
			   flume_status_cb_t cb);

    void getlabelset_impl (int fd, const str &fn, 
			   frozen_labelset_t *in, 
			   flume_status_cb_t cb);
  };

  class ghetto_ea_mgr_t : public ea_mgr_t {
  public:
    ghetto_ea_mgr_t (idd::server_handle_t *i) : _idd (i) { assert (i); }
    ~ghetto_ea_mgr_t () {}
    
    void setlabelset_impl (int fd, const str &fn, 
			   const frozen_labelset_t &in, 
			   flume_status_cb_t cb) 
    { setlabelset_impl_T (fd, fn, in, cb); }

    void getlabelset_impl (int fd, const str &fn, 
			   frozen_labelset_t *in, 
			   flume_status_cb_t cb)
    { getlabelset_impl_T (fd, fn, in, cb); }

  private:
    void setlabelset_impl_T (int fd, str fn, 
			     const frozen_labelset_t &in, 
			     flume_status_cb_t cb, CLOSURE);

    void getlabelset_impl_T (int fd, str fn, 
			     frozen_labelset_t *in, 
			     flume_status_cb_t cb, CLOSURE);

    idd::server_handle_t *_idd;
  };

  struct cfg_t : public base_cfg_t {

    cfg_t () : 
      base_cfg_t (),
      _readonly (false), 
      _public (false),
      _n_aiods (fs::default_naiods),
      _shmsize (fs::default_aiod_shmsize),
      _maxbuf (fs::default_aiod_maxbuf),
      _n_proc (fs::default_n_proc),
      _idd (NULL),
      _integrity_ns (false),
      _ghetto_eas (false),
      _miss_cache_lifetime (0),
      _optmz (false) {}
    
    bool parseopts (int argc, char *const argv[], str loc);
    bool to_argv (vec<str> *argv) const;
    bool no_ext_attr () const { return _public && _readonly; }
    void init ();
    bool has_minimum_label ();

    idd::server_handle_t *idd () { return _idd; }
    const str &handle_seed () const { return _handle_seed; }
    ptr<ea_mgr_t> ea_mgr () { return _ea_mgr; }
    void set_idd (const idd::server_handle_t *idd);
    void init_idd (cbb cb, CLOSURE);
    void init_ea_mgr ();
    void set_handle_seed (const str &s) { _handle_seed = s; }

    void simple_init (bool ghetto, const str &idd, cbb cb, CLOSURE);

    str to_str () const;
    ptr<const labelset_t> def_ls ();
    ptr<const labelset_t> def_root_ls ();
    
    ptr<argv_t> _env;
    str _prog;
    str _root;
    str _mountpoint;
    bool _readonly;
    bool _public;
    int _n_aiods;
    size_t _shmsize, _maxbuf;
    size_t _n_proc;
    idd::cfg_t _idd_cfg;
  private:
    idd::server_handle_t *_idd;
    ptr<ea_mgr_t> _ea_mgr;
  public:
    bool _integrity_ns;
    bool _ghetto_eas;
    ptr<labelset_t> _ls;
    ptr<labelset_t> _root_ls;
    ptr<labelset_t> _def_root_ls ();
    int _miss_cache_lifetime;
    bool _optmz;
  private:
    str _handle_seed;
  };


  bool path_split (vec<str> *out, str *np, const str &in);
  str dedotify (const str &in, vec<str> *out = NULL);
  bool is_legal_filename (const str &s);
  str combine_and_normalize (const str &cwd, const str &path, vec<str> *out);
  str flatten (const vec<str> &in, bool abs, bool dir);
  bool in_same_dir (const vec<str> &p1, const vec<str> &p2);
  str paste (const str &mount, const str &file);
  str top_level_fix (const str &in);
  bool is_root (const str &in);
  bool has_minimum_label ();

  void stat2xdr (const struct stat &sb, x_stat_t *sb);
  void xdr2timeval (const x_timeval_t &in, struct timeval *out);

  flume_status_t errno2err (bool pdir = false);
};

#endif /* _LIBFLUME_FSUTIL_H_ */
