
// -*-c++-*-

#include "async.h"
#include "crypt.h"
#include "endpoint.h"
#include "rm.h"
#include "flume_idd_prot.h"
#include "asyncutil.h"
#include "evalctx.h"

namespace rm {

  //-----------------------------------------------------------------------

  bool 
  endpoint_id_t::eq (const endpoint_id_t &e2) const
  {
    return (*_labelset == *e2._labelset &&
	    _mode == e2._mode &&
	    _mutable == e2._mutable);
  }

  //-----------------------------------------------------------------------

  hash_t 
  endpoint_id_t::hsh () const
  {
    return (_labelset->hsh () ^ (_mode << 10) ^ (_mutable << 20));
  }

  //-----------------------------------------------------------------------

  tamed void
  endpoint_t::check_add_sub_all (ptr<const label_t> l, 
				 evi_t cb, 
				 ptr<const labelset_t> tmp_ls,
				 ptr<eval::ctx_t> ctx)
  {
    tvars {
      ptr<hmgr_t> hmgr; 
      int rc;
    }

    hmgr = New refcounted<hmgr_t> (tmp_ls ? tmp_ls : _proc_labelset, 
				   _proc_filterset);

    twait { hmgr->check_add_sub_all (l, mkevent (rc), ctx); }
    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  //
  // If my label is 'me', and if the proc's label is 'proc', and the
  // new proclabel set is 'new_proc_ls', check that the endpoint 
  // configuration is valid.
  //
  tamed void
  endpoint_t::check_label (ptr<const label_t> me, 
			   ptr<const label_t> proc, 
			   label_type_t typ,
			   evb_t cb,
			   ptr<const labelset_t> new_proc_ls,
			   ptr<eval::ctx_t> ctx) 
  {
    tvars {
      ptr<label_t> tmp (New refcounted<label_t> ());
      int rc;
      bool rd;
      bool wr;
      bool res (true);
    }

    // only need to check the case in which the label is actually
    // being changed (proc is non-NULL) and the label does not
    // default to be the proc's (i.e., me is non-NULL)
    if (me && proc) {

      rd = _id._mode & EP_READ;
      wr = _id._mode & EP_WRITE;
      
      if ( (rd && typ == LABEL_I) || (wr && typ == LABEL_S) )
	// Compute tmp += (proc - me)
	proc->subtract (*me, tmp);
      
      if ( (rd && typ == LABEL_S) || (wr && typ == LABEL_I) )
	// Compute tmp += (me - proc)
	me->subtract (*proc, tmp);
      
      // tmp now contains all of the necessary differences between
      // this EP's label, and the parent's new proc label.  Check
      // that we have sufficient capabilities to maintain this difference.
      twait { check_add_sub_all (tmp, mkevent (rc), new_proc_ls, ctx); }
      
      if (rc != 1) {
	if (ctx) {
	  const char *l = labeltyp2str (typ);
	  str i = get_info ();
	  ctx->error ("Check endpoint label (" , l , ") failed for EP '", i,
		      "': don't have all capabilities for difference label ",
		      *tmp, " where this EP label is ", *me,
		      " and the process's label is ", *proc);
	}
	res = false;
      }
    }

    cb->trigger (res);
  }

  
  //-----------------------------------------------------------------------
  
  // 
  // If the given endpoint is valid, then insert into into this proc's
  // list of endpoints.
  //
  tamed void
  endpoint_t::check_and_set_proc (proc_label_bundle_t *b, evb_t ev,
				  ptr<eval::ctx_t> ctx)
  {
    tvars {
      bool ok (false);
    }

    assert (!_associated);
    assert (!_proc_labelset);

    twait { check_ep_valid (b->labelset (), false, mkevent (ok), ctx); }
    if (ok) {
      set_proc_common (b);
    }
    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  void 
  endpoint_t::check_ep_valid_self (bool frc, evb_t ev, ptr<eval::ctx_t> ctx)
  { return check_ep_valid (_proc_labelset, frc, ev, ctx); }

  //-----------------------------------------------------------------------

  //
  // Check that the EP would be valid if the process labelset changed
  // to new_pl.  If the force flag is specified, then it's possible
  // to zero-out the EP endpoint, of course if the EP is mutable.
  //
  tamed void
  endpoint_t::check_ep_valid (ptr<const labelset_t> new_pl, bool frc, evb_t ev,
			      ptr<eval::ctx_t> ctx)
  {
    tvars {
      bool b (false);
      rcset_t<bool> rc (2, true);
      int i (0);
    }

    _to_clear = false;
    if (labelset()) {
      twait {
	check_label (labelset ()->S (), new_pl->S (), LABEL_S, 
		     mkevent (rc[i++]), new_pl, ctx);
	check_label (labelset()->I(), new_pl->I(), LABEL_I, 
		     mkevent (rc[i++]), new_pl, ctx);
      }
      b = rc.project ();
      if (!b && frc && get_mutable() && !_strict) {
	_to_clear = true;
	b = true;
      }
    } else {
      b = true;
    }

    ev->trigger (b);
  }

  //-----------------------------------------------------------------------

  tamed void
  endpoint_t::set_label_2 (ptr<label_t> nl, 
			   ptr<label_t> *out,
			   ptr<const label_t> proc, 
			   flume_status_cb_t cb,
			   label_type_t typ, 
			   ptr<eval::ctx_t> ctx)
  {
    tvars {
      flume_status_t res (FLUME_OK);
      bool rc;
    }
    if (nl) { 
      twait { check_label (nl, proc, typ, mkevent (rc)); }
      if (!rc) {
	res = FLUME_EPERM;
	if (ctx) {
	  const char *which = labeltyp2str (typ);
	  ctx->error ("Endpoint check failed for ", which ,
		      "label; endpoint cannot be set to ", *nl,
		      "when proc's label is ", *proc, 
		      "and proc's ownership is ", _proc_labelset->O());
	}
      }
    }
    if (res == FLUME_OK) {
      *out = nl;
      changed ();
    }

    cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  endpoint_t::set_labels (ptr<labelset_t> l, flume_status_cb_t cb,
			  ptr<eval::ctx_t> x)
  {
    tvars {
      rcset_t<flume_status_t> rc (2, FLUME_OK);
      int i (0);
      flume_status_t res;
    }

    if (!get_mutable()) {
      res = FLUME_EROFS;
    } else {
      twait {
	set_label (LABEL_I, l->I (), mkevent (rc[i++]), x);
	set_label (LABEL_S, l->S (), mkevent (rc[i++]), x);
      }
      res = rc.project ();
    }
    cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  endpoint_t::set_label (label_type_t t, ptr<label_t> l, flume_status_cb_t cb,
			 ptr<eval::ctx_t> x)
  {
    tvars {
      flume_status_t res;
    }

    if (!labelset ())
      alloc_labelset ();

    switch (t) {
    case LABEL_I: 
      {
	twait { 
	  set_label_2 (l, labelset()->I_pointer (), _proc_labelset->I(), 
		       mkevent (res), LABEL_I, x);
	}
	break;
      }
    case LABEL_S: 
      { 
	twait { 
	  set_label_2 (l, labelset()->S_pointer (), _proc_labelset->S(), 
		       mkevent (res), LABEL_S, x);
	}
	break;
      }
    default:
      res = FLUME_UNHANDLED;
      break;
    }
    
    cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  // for sockets, no known parent; or for parent/child exit/wait channels
  endpoint_t::endpoint_t (endpoint_mode_t mode,
			  const str &nm)
    : _id (NULL, mode, true),
      _in_lookup_tab (false),
      _to_clear (false),
      _associated (false),
      _strict (false),
      _desc (nm) {}

  //-----------------------------------------------------------------------

  // for files, of course, parent is known
  endpoint_t::endpoint_t (ptr<labelset_t> ls,
			  endpoint_mode_t mode, 
			  ptr<const labelset_t> pls,
			  ptr<const filterset_t> pfs,
			  const str &nm)
    : _id (ls, mode, false),
      _proc_labelset (pls),
      _proc_filterset (pfs),
      _in_lookup_tab (false),
      _to_clear (false),
      _associated (true),
      _strict (false),
      _desc (nm) 
  { assert (pls); }

  //-----------------------------------------------------------------------

  // For EP bottom
  endpoint_t::endpoint_t ()
    : _id (New refcounted<labelset_t>(LABEL_NO_O), EP_RW, false),
      _in_lookup_tab (false),
      _to_clear (false),
      _associated (true),
      _strict (false),
      _desc ("bottom")
  {}

  //-----------------------------------------------------------------------

  endpoint_t::~endpoint_t ()
  {
    if (_lbund) {
      // Must be a mutable endpoint associated with a socket.
      assert (get_mutable ());
      _lbund->remove (this);
    }
  }

  //-----------------------------------------------------------------------

  /*
   * This function is called when an endpoint is out in the wild,
   * and a process has claimed it.
   */
  void
  endpoint_t::set_proc (proc_label_bundle_t *b)
  {
    assert (!_associated);
    assert (!_proc_labelset);

    set_proc_common (b);
    FLUMEDBG4(SOCKETS, CHATTER, 
	     "set_proc_lsw prompted potential label change: %p\n", this);
    changed ();
  }

  //-----------------------------------------------------------------------

  //
  // set_proc guts common to both set_proc and check_and_set_proc
  //
  void
  endpoint_t::set_proc_common (proc_label_bundle_t *b)
  {
    b->insert (mkref (this), false, false);
    _associated = true;
    _proc_labelset = b->labelset ();
    _lbund = b;
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_label_bundle_t::check_and_insert (ptr<endpoint_t> ep,
					 bool uniq, bool hold, evb_t ev)
  {
    tvars {
      bool ok;
    }
    twait { ep->check_ep_valid (labelset (), false, mkevent (ok)); }
    if (ok) {

      // Return of ::insert just tells us if the endpoint is unique
      // or not.
      (void )insert (ep, uniq, hold);
    }
    ev->trigger (ok);
  }
					 

  //-----------------------------------------------------------------------

  bool
  proc_label_bundle_t::insert (ptr<endpoint_t> s, bool uniq, bool hold)
  {
    assert (s);

    if (uniq) {

      assert (s->labelset ());

      if (_tab[s->_id])
	return false;

      s->set_in_lookup_tab (true);
      _tab.insert (s);
    }

    if (hold)
      s->holdme ();
    
    _endpoints.insert_head (s);
    _n_endpoints++;

    return true;
  }

  //-----------------------------------------------------------------------

  void
  proc_label_bundle_t::remove (endpoint_t *s)
  {
    if (s->in_lookup_tab ()) {
      _tab.remove (s);
    }
    _endpoints.remove (s);
    _n_endpoints --;
    s->unref ();
  }

  //-----------------------------------------------------------------------

  void endpoint_t::holdme () { _hold = mkref (this); }

  //-----------------------------------------------------------------------


  void 
  endpoint_t::unref ()
  {
    ptr<endpoint_t> h = _hold;
    _hold = NULL;
    h = NULL;
  }

  //-----------------------------------------------------------------------

  void 
  proc_label_bundle_t::clean_files ()
  {
    endpoint_t *n, *p;

    for (p = _endpoints.first; p; p = n) {
      n = _endpoints.next (p);
      if (p->is_file ())
	remove (p);
    }
  }

  //-----------------------------------------------------------------------

  void
  proc_label_bundle_t::remove_all ()
  {
    endpoint_t *e;
    while ((e = _endpoints.first))
      remove (e);
  }

  //-----------------------------------------------------------------------

  template<class T> ptr<T> 
  mymkref (T *in)
  {
    if (in) return mkref (in);
    else return NULL;
  }

  //-----------------------------------------------------------------------

  void
  proc_label_bundle_t::changed ()
  {
    FLUMEDBG4(SOCKETS,CHATTER, "Process labelset changed: proc=%p\n", this);

    ptr<endpoint_t> s, n;
    for (s = mymkref (_endpoints.first); s; s = n) {
      n = mymkref (_endpoints.next (s));
      s->changed ();
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  endpoint_t::invalidate_labels (int which, cbv cb)
  {
    tvars {
      bool r1 (true), r2 (true);
    }
    
    twait { 
      if (which & int(LABEL_S)) check_S_label (mkevent (r1));
      if (which & int(LABEL_I)) check_I_label (mkevent (r2)); 
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  endpoint_t::check_S_label (evb_t cb)
  {
    tvars {
      bool ret (true);
    }
    if (labelset() && labelset()->S()) {
      twait { 
	check_label (labelset()->S(), _proc_labelset->S(), 
		     LABEL_S, mkevent (ret));
      }
    }
    if (!ret) labelset()->clear_S ();
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  endpoint_t::check_I_label (evb_t cb)
  {
    tvars {
      bool ret (true);
    }
    if (labelset() && labelset()->I()) {
      twait { 
	check_label (labelset()->I(), _proc_labelset->I(), 
		     LABEL_I, mkevent (ret)); 
      }
    }
    if (!ret) labelset()->clear_I ();
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_label_bundle_t::check_ep_validity (ptr<labelset_t> nl, 
					  bool frc, 
					  ptr<eval::ctx_t> ctx, 
					  evb_t ev)
  {
    tvars {
      endpoint_t *n, *p;
      vec<bool> v;
      bool res (true);
      size_t i;
    }

    // 
    // Must size the vector first statically, and then given out
    // references to it!  A previous attempt tried to grow the vector
    // each time through, which made a mess, and wrote to freed memory.
    //
    v.setsize (_n_endpoints);

    //
    // Note, cannot do the following in serial unless we protect
    // the endpoints list across blocking calls.  That might be tricky,
    // so we'll just do everything at once.
    //
    twait { 
      for (p = _endpoints.first, i = 0; p ; p = n, i++) {
	n = _endpoints.next (p);
	p->check_ep_valid (nl, frc, mkevent (v[i]), ctx);
      }
    }
    for (i = 0; res && i < _n_endpoints; i++) { res = v[i]; }

    ev->trigger (res);
  }

  //-----------------------------------------------------------------------

  //
  // Precondition: own lock on this label bundle.
  //
  tamed void
  proc_label_bundle_t::perform_ep_change (ptr<labelset_t> nl, 
					ptr<eval::ctx_t> ctx,
					evb_t ev,
					bool force)
  {
    tvars {
      bool ok;
    }

    twait { check_ep_validity (nl, force, ctx, mkevent (ok)); }
    if (force) {
      for (endpoint_t *p = _endpoints.first ; p ; p = _endpoints.next (p)) {
	p->clear_if_necessary (ok);
      }
    }
    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  void
  endpoint_t::clear_if_necessary (bool ok)
  {
    if (ok && _to_clear) {
      _cached_effective_labelset = NULL;
      _id._labelset = NULL;
    }
    _to_clear = false;
  }

  //-----------------------------------------------------------------------

  proc_label_bundle_t::proc_label_bundle_t (int which)
    : _labelset (New refcounted<labelset_t> (which)),
      _n_endpoints (0) {}

  //-----------------------------------------------------------------------

   proc_label_bundle_t::proc_label_bundle_t (ptr<labelset_t> l) 
     : _labelset (l),
       _n_endpoints (0) {}

  //-----------------------------------------------------------------------

  ptr<proc_label_bundle_t>
  proc_label_bundle_t::clone () const
  {
    return New refcounted<proc_label_bundle_t> 
      (_labelset->deep_clone (LABEL_ALL));
  }


  //-----------------------------------------------------------------------

  proc_label_bundle_t::~proc_label_bundle_t ()
  {
    remove_all ();
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_label_bundle_t::can_switch_to (ptr<hmgr_t> hmgr,
				      ptr<const label_t> oldl,
				      ptr<const label_t> newl,
				      evi_t ev, 
				      ptr<eval::ctx_t> ctx)
  {
    tvars {
      rcset_t<int> rcs (2, 1);
      int rc;
    }
    twait {
      do_subset (hmgr, newl, oldl, COMPARE_ADD, mkevent (rcs[0]), "+", ctx);
      do_subset (hmgr, oldl, newl, COMPARE_SUBTRACT, mkevent (rcs[1]), 
		 "-", ctx);
    }
    rc = rcs.project ();

    if (rc != 1 && ctx) {
      ctx->error ("can_switch_to() failed");
    }

    ev->trigger (rc);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_label_bundle_t::do_subset (ptr<hmgr_t> hmgr,
				  ptr<const label_t> lhs, 
				  ptr<const label_t> rhs,
				  setcmp_type_t op, cbi cb, 
				  const char *op_s,
				  ptr<eval::ctx_t> ctx)
  {
    tvars {
      int rc;
    }
    twait { hmgr->subset_of (lhs, O(), rhs, op, mkevent (rc), ctx); }
    if (rc != 1) {
      if (ctx) {
	ctx->error ("subset_of(", op_s, ") operation failed; ",
		    lhs,
		    "is not a subset of ",
		    rhs, "under ownership ",
		    O());
      }
    }
    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_label_bundle_t::set_proc_label (ptr<hmgr_t> hmgr,
				       int which,
				       ptr<const label_t> oldl,
				       ptr<label_t> newl,
				       evb_t ev,
				       ptr<eval::ctx_t> ctx,
				       cb_cls_t::ptr pre_change_hook,
				       bool force)
  {
    tvars {
      int rc;
      bool ok;
      ptr<proc_label_bundle_t> hold;
      ptr<labelset_t> tls;
    }

    assert (which != LABEL_O);

    hold = mkref (this);

    twait { acquire_lock (tame::lock_t::EXCLUSIVE, mkevent ()); }
    twait { can_switch_to (hmgr, oldl, newl, mkevent (rc), ctx); }
    if (rc > 0) {
      tls = clone_labelset ();
      tls->set_label (which, newl);
      twait { perform_ep_change (tls, ctx, mkevent (ok), force); }
    } else {
      ok = false;
    }

    if (ok) {

      if (pre_change_hook) {
	// Execute with the updated copy, to avoid bad/leaky race condition
	ptr<labelset_t> nls = labelset ()->clone (LABEL_ALL);
	nls->set_label (which, newl);
	(*pre_change_hook) (nls);
      }

      _labelset->set_label (which, newl);
    }

    release_lock ();

    if (ok) {
      // XXX can optimize this to not do as much work based on which
      // labels changed and how they changed; however, for now, do
      // the simplest thing.
      changed ();
    }

    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  ptr<labelset_t> 
  proc_label_bundle_t::clone_labelset () const
  {
    ptr<labelset_t> tls;
    if (labelset ()) { tls = New refcounted<labelset_t> (*labelset ()); }
    else { tls = New refcounted<labelset_t> (); }
    return tls;
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_label_bundle_t::set_proc_O_label (ptr<hmgr_t> hmgr,
					 ptr<const capset_t> caps, 
					 ptr<capset_t> newl,
					 evb_t ev,
					 ptr<eval::ctx_t> ctx,
					 cb_cls_t::ptr pre_change_hook,
					 bool force)
  {
    tvars {
      int rc;
      bool ok;
      ptr<proc_label_bundle_t> hold;
      ptr<labelset_t> tls;
    }

    hold = mkref (this);
    twait { acquire_lock (tame::lock_t::EXCLUSIVE, mkevent ()); }
    twait { 
      hmgr->subset_of (newl, O(), caps, COMPARE_NONE, mkevent (rc)); 
    }
    if (rc > 0) {
      tls = clone_labelset ();
      tls->set_O (newl);
      twait { perform_ep_change (tls, ctx, mkevent (ok), force); }
    } else {
      ok = false;
    }

    if (ok) {
      if (pre_change_hook) {
	ptr<labelset_t> nls = labelset ()->clone (LABEL_ALL);
	nls->set_O (newl);
	(*pre_change_hook) (nls);
      }
      _labelset->set_O (newl);
    }

    release_lock ();

    if (ok) {
      // See note above.
      changed ();
    }

    ev->trigger (ok);
  }
      
  //-----------------------------------------------------------------------

  void
  proc_label_bundle_t::get_endpoint_info (x_endpoint_set_t *out) const
  {
    out->setsize (_n_endpoints);
    endpoint_t *p;
    size_t i = 0;
    for (p = _endpoints.first; p;  p = _endpoints.next (p), i++) {
      assert (i < _n_endpoints);
      p->get_info (&((*out)[i]));
    }

  }

  //-----------------------------------------------------------------------

  void
  endpoint_id_t::get_info (x_endpoint_t *out) const
  {
    if (_labelset) {
      if (_labelset->S()) _labelset->S()->to_xdr (&out->S); 
      if (_labelset->I()) _labelset->I()->to_xdr (&out->I); 
    }
    out->attributes = u_int(_mode) | (_mutable ? u_int(EP_MUTABLE) : 0);
  }

  //-----------------------------------------------------------------------

  str
  endpoint_id_t::get_info () const
  {
    strbuf b;
    if (_mode & EP_READ)  { b << "r"; }
    if (_mode & EP_WRITE) { b << "w"; }
    if (_mutable)         { b << "m"; }
    return b;
  }

  //-----------------------------------------------------------------------

  str
  endpoint_t::get_info () const
  {
    str s = _id.get_info ();
    strbuf b;
    if (_desc) {
      b << _desc;
    } else {
      b << "(anon)";
    }
    b << " [" << s << "]";
    return b;
  }

  //-----------------------------------------------------------------------

  void
  endpoint_t::get_info (x_endpoint_t *x) const
  {
    if (_desc)
      x->desc = _desc;
    _id.get_info (x);
  }

  //-----------------------------------------------------------------------

  void
  endpoint_id_t::set_labelset (const x_labelset_t *x)
  {
    if (x) {
      _labelset = New refcounted<labelset_t> (*x);
    } else {
      _labelset= NULL;
    }
  }

  //-----------------------------------------------------------------------


  void
  endpoint_t::set (const x_endpoint_t *x)
  {
    ptr<labelset_t> ls;
    if (x) {
      ls = New refcounted<labelset_t> ();
      if (x->S) ls->set_S (New refcounted<label_t> (x->S));
      if (x->I) ls->set_I (New refcounted<label_t> (x->I));
    }
    _id.set_labelset (ls);

    // XXX maybe set the other fields, too?
  }

  //-----------------------------------------------------------------------

  void
  endpoint_t::effective_labelset (ptr<const labelset_t> *out) const
  {
    effective_labelset (_proc_labelset, true, out);
  }

  //-----------------------------------------------------------------------

  void
  endpoint_t::effective_labelset (ptr<const labelset_t> proc, 
				  bool use_cache,
				  ptr<const labelset_t> *out) const
  {
    ptr<const labelset_t> r;
      
    // optimization -- common case is no per-fd label, so just
    // use the pointer and don't incur the additional memcopies.

    if (labelset () && (labelset()->S () || labelset()->I ())) {

      // Accessed the cached output of this computation, but make
      // sure to invalidate whenever the per-FD or the underlying
      // process label changes.
      if (use_cache && _cached_effective_labelset) {
	r = _cached_effective_labelset;
      } else if (labelset()->S() && labelset()->I()) {
	r = labelset();
      } else {
	ptr<labelset_t> t = New refcounted<labelset_t> (*labelset());
	if (!t->S () && proc->S ()) 
	  t->set_S (New refcounted<label_t> (*proc->S()));
	if (!t->I () && proc->I ()) 
	  t->set_I (New refcounted<label_t> (*proc->I()));
	if (use_cache) {
	  _cached_effective_labelset = t;
	}
	r = t;
      }
      *out = r;

      if (FLUMEDBG2(LABELOPS)) {
	str s1 = labelset()->to_str ();
	str s2 = proc->to_str ();
	str s3 = r->to_str ();
	flumedbg_warn (CHATTER, "Effective labelset made: %s + %s => %s\n", 
		      s1.cstr (), s2.cstr (), s3.cstr ());
      }
    } else {
      assert (proc);
      *out = proc;
      if (FLUMEDBG2(LABELOPS)) {
	str s1 = proc->to_str ();
	flumedbg_warn (CHATTER, "No EP label; Effective labelset returns "
		       "proc label: %s\n", s1.cstr ());
      }
    }
  }

  //-----------------------------------------------------------------------

  //
  // Determine if this endpoint is less than another in one of two ways.
  // If 'myproc' was specified, use that labelset for this proc's labelset.
  // If not, use the proc's actual labelset for the proc's labelset. The
  // reason for this complication is to stop race conditions.  We first
  // change process exit statuses based on their new label, and then
  // actually make the label change.
  //
  bool 
  endpoint_t::leq (const endpoint_t *rhs, ptr<const labelset_t> myproc) const
  {
    ptr<const labelset_t> me;
    ptr<const labelset_t> them;

    if (myproc) effective_labelset (myproc, false, &me);
    else        effective_labelset (&me);

    rhs->effective_labelset (&them);

    assert (me);
    assert (them);

    bool ret = (*me <= *them);
    if (FLUMEDBG2(LABELOPS)) {
      str s1 = me->to_str ();
      str s2 = them->to_str ();
      flumedbg_warn (CHATTER, "EP comparison: { %s <= %s } yields %d\n",
		     s1.cstr (), s2.cstr (), ret);
    }
    return ret;
  }

  //-----------------------------------------------------------------------

  void
  endpoint_t::fix ()
  {
    assert (_proc_labelset);
    assert (get_mutable ());
    _id._labelset = _proc_labelset->deep_clone (LABEL_NO_O);
  }

};
