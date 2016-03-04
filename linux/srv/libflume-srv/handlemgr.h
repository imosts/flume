
// -*-c++-*-

#include "flume_prot.h"
#include "ihash.h"
#include "qhash.h"
#include "flume_bf60.h"
#include "tame.h"
#include "iddutil.h"
#include "flume_ev_labels.h"
#include "evalctx.h"
#include "filter.h"

#ifndef __LIBFLUME_HANDLEMGR_H__
#define __LIBFLUME_HANDLEMGR_H__


//-----------------------------------------------------------------------
// handle_mgr = "handle manager"
//
//    Master of all label operations for this particular process; has
//    a connection to IDD that might call IDD during label Ops.
//


template<class T> 
class bfsq_t : public vec<T> {
public:
  bfsq_t () : vec<T> () {}
  void enqueue (const T &t) 
  {
    if (!_h[t]) {
      push_back (t);
      _h.insert (t);
    }
  }
private:
  bhash<T> _h;
};

typedef callback<void, flume_status_t, handle_t>::ref nhcb_t;
typedef callback<void, flume_status_t, handle_t, handle_t>::ref ngcb_t;

// A global handlemgr is needed for the whole RM, just to keep
// track of a connection to IDD and also a handle factory for local
// handles.
class global_handlemgr_t {
public:
  global_handlemgr_t (idd::server_handle_t *i, const str &seed = NULL);
  ~global_handlemgr_t ();

  handle_factory_t *hfact () { return _f; }
  idd::server_handle_t *idd () { return _idd; }
  
private:
  idd::server_handle_t *_idd;
  handle_factory_t *_f;
};

extern global_handlemgr_t *global_handlemgr;

void global_idd_init (idd::server_handle_t *idd, const str &seed);

// A per-process handle manager
class perproc_handlemgr_t : public virtual refcount {
public:
  perproc_handlemgr_t (ptr<const labelset_t> l, ptr<const filterset_t> f)
    : _gmgr (global_handlemgr), _c_labelset (l), _c_filterset (f) {}

  void contains (handle_t g, capability_t h, evb_t cb, 
		 ptr<eval::ctx_t> ctx = NULL,
		 CLOSURE);

  idd::server_handle_t *idd () { return _gmgr->idd (); }
  handle_factory_t *hfact () { return _gmgr->hfact (); }
  
  void lookup_labels (handle_t h, labelset_t *ls, flume_status_cb_t cb, 
		      CLOSURE);
protected:
  
  void can_search (handle_t g, cbb cb, 
		   ptr<eval::ctx_t> ctx = NULL,
		   CLOSURE);
  void can_write (handle_t g, cbb cb, ptr<eval::ctx_t> ctx = NULL, CLOSURE);

  void
  explore (capability_t h, bfsq_t<handle_t> *q, bool *f, 
	   ptr<bool> running, evv_t ev, CLOSURE);

  void
  check_for_cap (capability_t h, const vec<handle_t> *g, evb_t cb, 
		 ptr<eval::ctx_t> cvs = NULL, CLOSURE);

public:

  // check if we can add and subtract all handles in the label
  void check_add_sub_all (ptr<const label_t> l, cbi cb, 
			  ptr<eval::ctx_t> ctx = NULL, CLOSURE);


  // Check this filter for internal consistency
  void check_filter (const filter_t &f, const req_privs_arg_t *rpa,
		     flume_status_cb_t cb, 
		     ptr<eval::ctx_t> ctx = NULL, CLOSURE);

  // Check if h \in_p r
  void contained_in (handle_t h, const label_t *r, cbi cb, 
		     ptr<eval::ctx_t> ctx = NULL, CLOSURE);

  // Check if x intersects y at all
  void intersects (const label_t *x, const label_t *y, cbi cb, 
		   ptr<eval::ctx_t> ctx = NULL, CLOSURE);

  // Check if either y is empty, or if x intersects y
  void cap_intersects (const capset_t *x, const capset_t *y, cbi cb, 
		       ptr<eval::ctx_t> ctx = NULL, CLOSURE);

  // Test if l [= (r1 U r2 U r3 ...)
  void subset_of (const label_t *lhs, const label_t **v, 
		  setcmp_type_t typ, cbi cb, 
		  ptr<eval::ctx_t> ctx = NULL,
		  CLOSURE) ;

  void subset_of (const label_t *lhs, setcmp_type_t typ, cbi cb,
		  ptr<eval::ctx_t> ctx = NULL)
  { subset_of_0 (lhs, typ, cb, ctx); }

  void subset_of (const label_t *lhs, const label_t *r1, 
		  setcmp_type_t typ, cbi cb,
		  ptr<eval::ctx_t> ctx = NULL)
  { subset_of_1 (lhs, r1, typ, cb, ctx); }

  void subset_of (const label_t *lhs, const label_t *r1, 
		  const label_t *r2, setcmp_type_t typ, cbi cb,
		  ptr<eval::ctx_t> ctx = NULL)
  { subset_of_2 (lhs, r1, r2, typ, cb, ctx); }
  
  void subset_of (const label_t *lhs, const label_t *r1, 
		  const label_t *r2, const label_t *r3, 
		  setcmp_type_t typ, cbi cb,
		  ptr<eval::ctx_t> ctx = NULL)
  { subset_of_3 (lhs, r1, r2, r3, typ, cb, ctx); }

  
protected:
  void subset_of_3 (const label_t *lhs, const label_t *r1, 
		    const label_t *r2, const label_t *r3, 
		    setcmp_type_t typ, cbi cb,
		    ptr<eval::ctx_t> ctx = NULL, CLOSURE);
  void subset_of_2 (const label_t *lhs, const label_t *r1, 
		    const label_t *r2, setcmp_type_t typ, cbi cb,
		    ptr<eval::ctx_t> ctx = NULL, CLOSURE);
  void subset_of_1 (const label_t *lhs, const label_t *r1, 
		    setcmp_type_t typ, cbi cb,
		    ptr<eval::ctx_t> ctx = NULL, CLOSURE);
  void subset_of_0 (const label_t *lhs, setcmp_type_t typ, cbi cb,
		    ptr<eval::ctx_t> ctx = NULL, CLOSURE);

  global_handlemgr_t* _gmgr;
  ptr<const labelset_t>     _c_labelset;
  ptr<const filterset_t>    _c_filterset;
};

class mutating_perproc_handlemgr_t : public perproc_handlemgr_t 
{
public:
  mutating_perproc_handlemgr_t (ptr<labelset_t> l, ptr<const filterset_t> f)
    : perproc_handlemgr_t (l, f), _labelset (l) {}

  static ptr<mutating_perproc_handlemgr_t> 
  alloc (ptr<labelset_t> l, ptr<const filterset_t> f)
  { return New refcounted<mutating_perproc_handlemgr_t> (l, f); }

  void group_union_in (handle_t g, const x_handlevec_t *t,
		       flume_status_cb_t cb, ptr<eval::ctx_t> ctx = NULL, 
		       CLOSURE);

  void new_handle (const new_handle_arg_t *a, new_handle_res_t *r, cbv c,
		   CLOSURE);

  void new_group (const new_group_arg_t *a, new_group_res_t *r, 
		  cbv c, CLOSURE);

  void new_group_unsafe (const str &n, const labelset_t &s,
			 new_group_res_t *rs, cbv cb, CLOSURE);

  void group_union_in_unsafe (handle_t g, const x_handlevec_t *x,
			      flume_status_cb_t cb, 
			      ptr<eval::ctx_t> ctx = NULL,
			      CLOSURE);
protected:
  void made_new_handle (handle_t h);

  ptr<labelset_t>           _labelset;
};

typedef mutating_perproc_handlemgr_t mhmgr_t;

typedef perproc_handlemgr_t hmgr_t;


//
// End handlemgr stuff
//-----------------------------------------------------------------------


#endif /* __LIBFLUME_HANDLEMGR_H__ */
