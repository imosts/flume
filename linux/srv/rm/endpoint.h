// -*-c++-*-
#ifndef _RM_ENDPOINT_H_
#define _RM_ENDPOINT_H_

#include "flume.h"
#include "arpc.h"
#include "asyncutil.h"
#include "flume_prot.h"
#include "flume_srv_const.h"
#include "unixutil.h"
#include "tame.h"
#include "mounttree2.h"
#include "flume_fs_prot.h"
#include "fsutil.h"
#include "iddutil.h"
#include "tame_lock.h"
#include "tame_pc.h"
#include "handlemgr.h"
#include "spawnutil.h"
#include "evalctx.h"
#include "filter.h"
#include "tame_lock.h"

namespace rm {

  class proc_label_bundle_t;

  struct endpoint_id_t {
    endpoint_id_t (ptr<labelset_t> l, endpoint_mode_t mode, mode_t mut)
      : _labelset (l), _mode (mode), _mutable (mut) {}

    bool eq (const endpoint_id_t &e2) const;
    hash_t hsh () const;

    void alloc_labelset () 
    { _labelset = New refcounted<labelset_t> (LABEL_NO_O); }

    bool operator== (const endpoint_id_t &e2) const { return eq (e2); }

    void get_info (x_endpoint_t *out) const;
    str get_info () const;

    void set_labelset (const x_labelset_t *x);
    void set_labelset (ptr<labelset_t> l) { _labelset = l; }

    ptr<labelset_t> _labelset;
    endpoint_mode_t _mode;
    bool            _mutable;
  };
};

template<> struct equals<rm::endpoint_id_t>
{
  equals () {}
  bool operator() (const rm::endpoint_id_t &e1, 
		   const rm::endpoint_id_t &e2) const
  {
      return (e1 == e2);
  }
};

template<> struct hashfn<rm::endpoint_id_t>
{
  hashfn () {}
  hash_t operator() (const rm::endpoint_id_t &e) const { return e.hsh (); }
};

namespace rm {

  class endpoint_t : public virtual refcount {
  public:

    // For associating with sockets
    endpoint_t (endpoint_mode_t m,
		const str &nm = NULL);


    // For associating with files
    endpoint_t (ptr<labelset_t> ls, endpoint_mode_t m, 
		ptr<const labelset_t> pls, 
		ptr<const filterset_t> pfs,
		const str &nm = NULL);

    // For making bottom endpoints
    endpoint_t ();

    virtual ~endpoint_t () ;

    bool in_lookup_tab () const { return _in_lookup_tab; }
    void set_in_lookup_tab (bool b) { _in_lookup_tab = b; }

    static ptr<endpoint_t> alloc_bottom ()
    { return New refcounted<endpoint_t> (); }
    
    void set_label (label_type_t t, ptr<label_t> l, flume_status_cb_t cb,
		    ptr<eval::ctx_t> ctx = NULL, CLOSURE);
    void set_labels (ptr<labelset_t> l, flume_status_cb_t cb, 
		     ptr<eval::ctx_t> x = NULL, CLOSURE);

    void set_proc (proc_label_bundle_t *b);

    void check_and_set_proc (proc_label_bundle_t *b, evb_t ev,
			     ptr<eval::ctx_t> ctx, CLOSURE);

    // Check that we add/subtract all handles in l,
    // given capabilities in tmp_ls.  If tmp_ls is NULL,
    // then just use _proc_labelset.
    void check_add_sub_all (ptr<const label_t> l, 
			    evi_t cb, 
			    ptr<const labelset_t> tmp_ls, 
			    ptr<eval::ctx_t> ctx,
			    CLOSURE);

    void invalidate_labels (int which, cbv cb, CLOSURE);

    // Call this whenever we've changed; subclasses might need to do 
    // something interesting.
    virtual void changed () {}

    // If the endpoint corresponds to an actual file.
    virtual bool is_file () const { return false; }

    //
    // Check if this endpoint would be valid if the proc label 
    // were to be changed to pl.
    //
    void check_ep_valid (ptr<const labelset_t> pl, bool frc, evb_t ev,
			 ptr<eval::ctx_t> ev = NULL, CLOSURE);
    
    //
    // Check if this endpoint is valid right now, without any
    // changes.
    //
    void check_ep_valid_self (bool frc, evb_t ev, ptr<eval::ctx_t> x = NULL);

    ptr<labelset_t> labelset () { return _id._labelset; }
    ptr<const labelset_t> labelset () const { return _id._labelset; }
    void alloc_labelset () { _id.alloc_labelset (); }

    bool get_mutable () const { return _id._mutable; }
    endpoint_mode_t mode () const { return _id._mode; }

    const str &desc () const { return _desc; }
    void set_desc (const str &s) { _desc = s; }
    void set_labelset (const x_labelset_t *x) { _id.set_labelset (x); }
    void set (const x_endpoint_t *x);

    // On the second sweep through endpoints, we clear all of those
    // endpoints that required clearing (if force mode was specified).
    void clear_if_necessary (bool ok);

    void get_info (x_endpoint_t *x) const;
    str get_info () const;

    void holdme ();
    void unref ();

    // Get the effective labelset for this endpoint.  This function
    // consults the process's labelset if necessary.
    void effective_labelset (ptr<const labelset_t> *out) const;

    // The more general version of the above function.
    void effective_labelset (ptr<const labelset_t> proc, bool use_cache,
			     ptr<const labelset_t> *out) const;

    // Check that this endpoint is LEQ some other RHS endpoint
    bool operator<= (const endpoint_t &e) const { return leq (&e); }
    bool leq (const endpoint_t *e, ptr<const labelset_t> p = NULL) const ;

    // A user program can set 'strict' bit so that this endpoint
    // won't be cleared on a labelchange that would want it to be cleared;
    // this would cause the label change to fail.
    void set_strict (bool b) { _strict = b; }


    // Fix this endpoint to be that of the process
    void fix ();

  public:
    
    //
    // Contains all of the info needed to uniquely identify this
    // endpoint, to check for duplicates in certain cases.  Also
    // contains the endpoint's labelset.
    //
    endpoint_id_t _id;

  protected:

    // A pointer to the parent process's labelset; can persist
    // past the death of the process.  It's const since endpoints
    // should only read, and not write their process's labelset.
    ptr<const labelset_t> _proc_labelset;
    ptr<const filterset_t> _proc_filterset;

    // Some combination of the parent proc's labelset, and our
    // labelset.
    mutable ptr<const labelset_t> _cached_effective_labelset;

    bool _in_lookup_tab;
    bool _to_clear;
    bool _associated;
    bool _strict;

    wkref_t<proc_label_bundle_t> _lbund;

    // User-assigned description, useful in debugging
    str _desc;

    // For keeping ourselves in scope....
    ptr<endpoint_t> _hold;

  protected:
    void check_I_label (evb_t, CLOSURE);
    void check_S_label (evb_t, CLOSURE);

    void check_label (ptr<const label_t> me, 
		      ptr<const label_t> proc,
		      label_type_t typ, 
		      evb_t cb, 
		      ptr<const labelset_t> new_proc_ls = NULL,
		      ptr<eval::ctx_t> ctx = NULL, CLOSURE);

    void set_label_2 (ptr<label_t> nl, 
		      ptr<label_t> *out,
		      ptr<const label_t> proc, 
		      flume_status_cb_t cb,
		      label_type_t typ, 
		      ptr<eval::ctx_t> x, CLOSURE);

  private:
    void set_proc_common (proc_label_bundle_t *b);

  public:
    // Data structures for inclusion in intrusive containers.
    ihash_entry<endpoint_t>  _hlnk;
    list_entry<endpoint_t>   _lnk;
  };

  // Endpoints that correspond to opened files
  class file_endpoint_t : public endpoint_t {
  public:
    file_endpoint_t (ptr<labelset_t> ls, endpoint_mode_t m,
		     ptr<const labelset_t> pls, 
		     ptr<const filterset_t> pfs,
		     const str &nm = NULL)
      : endpoint_t (ls, m, pls, pfs, nm) {}
    virtual ~file_endpoint_t () {}

    bool is_file () const { return true; }
  };

  typedef callback<void, ptr<const labelset_t> >::ref cb_cls_t;


  //
  // A collection of all of a process's labels, both the process-wide
  // label, and also links to all endpoints.  Factored out of the 
  // proc structure mainly to split up code across multiple classes
  // (and files). 
  //
  // To solve some small race conditions, functions can hold onto this
  // object even if the containing process goes out of scope and dies
  // (maybe).
  //
  class proc_label_bundle_t : public virtual refcount, public wkrefcount_t {
  public:
    proc_label_bundle_t (int which) ;
    proc_label_bundle_t (ptr<labelset_t> l) ;
    ~proc_label_bundle_t ();

    ptr<labelset_t> labelset () { return _labelset; }
    ptr<const labelset_t> labelset() const { return _labelset; }

    void set (ptr<labelset_t> l) 
    { 
      assert (!_endpoints.first);
      _labelset = l; 
    }

    ptr<proc_label_bundle_t> clone () const;

    void changed ();

    //
    // Insert an endpoint into the table, but first check that
    // it's valid.
    //
    void check_and_insert (ptr<endpoint_t> ep, bool frc, bool uniq,
			   evb_t ev, CLOSURE);

    //
    // Call this function to "test the waters" on the given update ---
    // i.e., to make sure that all endpoints will be valid if this
    // change were allowed to go through.
    //
    void check_ep_validity (ptr<labelset_t> nl, bool frc, ptr<eval::ctx_t> ctx,
			    evb_t ev, CLOSURE);

    void perform_ep_change (ptr<labelset_t> nl, ptr<eval::ctx_t> ctx, 
			    evb_t ev, bool force, CLOSURE);

    bool insert (ptr<endpoint_t> s, bool uniq, bool hold);
    void remove (endpoint_t *s);

    void acquire_lock (tame::lock_t::mode_t m, evv_t ev)
    { _lock.acquire (m, ev); }
    void release_lock () { _lock.release (); }
    bool is_locked () const { return _lock.mode () != tame::lock_t::OPEN; }

    // Clean out all file endpoints (if clients process has called
    // 'close_files').
    void clean_files ();

    
    void can_switch_to (ptr<hmgr_t> hmgr,
			ptr<const label_t> oldl,
			ptr<const label_t> newl,
			evi_t ev, 
			ptr<eval::ctx_t> ctx, CLOSURE);
    
    void do_subset (ptr<hmgr_t> hmgr,
		    ptr<const label_t> lhs, 
		    ptr<const label_t> rhs,
		    setcmp_type_t op, cbi cb, 
		    const char *op_s,
		    ptr<eval::ctx_t> ctx, CLOSURE);

    void set_proc_label (ptr<hmgr_t> hmgr,
			 int which,
			 ptr<const label_t> oldl,
			 ptr<label_t> newl,
			 evb_t ev,
			 ptr<eval::ctx_t> ctx, 
			 cb_cls_t::ptr pre_change_hook,
			 bool force,
			 CLOSURE);

    void set_proc_O_label (ptr<hmgr_t> hmgr,
			   ptr<const capset_t> caps,
			   ptr<capset_t> newl,
			   evb_t ev,
			   ptr<eval::ctx_t> ctx, 
			   cb_cls_t::ptr pre_change_hook,
			   bool force,
			   CLOSURE);

    void get_endpoint_info (x_endpoint_set_t *out) const;

  protected:
    void remove_all ();
    ptr<const capset_t> O () const { return labelset ()->O (); }

    ptr<labelset_t> clone_labelset () const;

  private:

    // A process-wide labelset
    ptr<labelset_t> _labelset;

    // All endpoints associated with this process
    list<endpoint_t, &endpoint_t::_lnk> _endpoints;

    // number of elements in the above list
    size_t _n_endpoints;

    // A lookup table of endpoints so that we don't add the same
    // endpoint a million times in the case of files.
    ihash<endpoint_id_t, endpoint_t, &endpoint_t::_id, 
	  &endpoint_t::_hlnk> _tab;

    // A lock used to synchronize access.
    tame::lock_t _lock;

  };

};

#endif /* _RM_ENDPOINT_H_ */
