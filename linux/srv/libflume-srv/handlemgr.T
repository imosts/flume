
// -*-c++-*-

#include "handlemgr.h"
#include "flume_idd_prot.h"
#include "flume_ev_debug.h"
#include "asyncutil.h"
#include "filter.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

//-----------------------------------------------------------------------

static str
debug_contains (handle_t h, handle_t g)
{
  strbuf b;
  b.cat (h.to_str (), true);
  b << " in ";
  b.cat (g.to_str () , true);
  return b;
}

//-----------------------------------------------------------------------

global_handlemgr_t::global_handlemgr_t (idd::server_handle_t *i, const str &s) 
  : _idd (i), _f (handle_factory_t::alloc (s)) {}

//-----------------------------------------------------------------------
  
global_handlemgr_t::~global_handlemgr_t ()
{
  delete _f;
}
  
//-----------------------------------------------------------------------

// One of these per RM process

global_handlemgr_t *global_handlemgr;


//-----------------------------------------------------------------------

void
mutating_perproc_handlemgr_t::made_new_handle (handle_t h)
{
  hfact ()->remote_alloc (h);
  ptr<capset_t> O = _labelset->O();
  if (O) {
    h.add_capabilities (O);
  }
}

//-----------------------------------------------------------------------

tamed void
mutating_perproc_handlemgr_t::new_handle (const new_handle_arg_t *arg, 
					  new_handle_res_t *res, cbv cb)
{
  tvars {
    clnt_stat err;
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);
  
  if (is_persistent (arg->prefix)) {
    twait { 
      idd ()->conn ()->call (IDD_NEW_HANDLE, arg, res, mkevent (err)); 
    }
    if (err) {
      warn << "** Error calling to IDD_NEW_HANDLE: " << err << "\n";
      res->set_status (FLUME_ERPC);
      *res->code = int (err);
    } else if (res->status != FLUME_OK) {
      warn << "Got back non-zero error from IDD: " << res->status << "\n";
    }
  } else {
    handle_t h = hfact ()->newh (arg->prefix, true);
    assert (h);
    res->set_status (FLUME_OK);
    *res->base_h = h;
  }
  
  if (res->status == FLUME_OK) {
    made_new_handle (*res->base_h);
  }
  cb->trigger ();
}

//-----------------------------------------------------------------------

tamed void
mutating_perproc_handlemgr_t::new_group (const new_group_arg_t *arg,
					 new_group_res_t *res, cbv cb)
{
  tvars {
    labelset_t s (arg->labels);
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  // First check that the caller gave a reasonable label to 
  // apply to this group.  If not, we have a problem...
  if (!( *_labelset <= s )) {
    res->set_status (FLUME_EPERM);
    strbuf b;
    str s1 = _labelset->to_str (LABEL_ALL);
    str s2 = s.to_str (LABEL_NO_O);
    b << "Process's LabelSet (" << s1 << ") must be less than the "
      <<  "new group's (" << s2 << ")";
    res->eperm->desc = b;
  } else {
    twait { new_group_unsafe (arg->name, s, res, mkevent ()); }
  }
  cb->trigger ();
}

//-----------------------------------------------------------------------

tamed void
mutating_perproc_handlemgr_t::new_group_unsafe (const str &n, 
						const labelset_t &s,
						new_group_res_t *res, cbv cb)
{
  tvars {
    clnt_stat err;
    idd_new_group_arg_t i_arg;
    flume_status_t stat;
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  twait { idd ()->freeze (&s, &i_arg.labels, mkevent (stat)); }
  if (stat != FLUME_OK) {
    warn << "Error in freezing handles: " << stat << "\n";
    res->set_status (stat);
  } else {
    i_arg.name = n;
    twait { 
      idd ()->conn ()->call (IDD_NEW_GROUP, &i_arg, res, mkevent (err)); 
    }
    if (err) {
      warn << "** Error calling to IDD_NEW_GROUP: " << err << "\n";
      res->set_status (FLUME_ERPC);
      *res->code = int (err);
    } else if (res->status != FLUME_OK) {
      warn << "Got error result from IDD: " << res->status << "\n";
    } else {
      made_new_handle (res->group->base_h);
    }
  }
  cb->trigger ();
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::explore (capability_t h, bfsq_t<handle_t> *q, bool *r, 
			      ptr<bool> running, evv_t ev)
{
  tvars {
    idd_member_of_arg_t arg;
    idd_member_of_res_t res;
    handle_t g;
    str debug_what;
    bool found (false);
    flume_status_t st;
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  arg.capability = h;
  g = q->pop_front ();
  arg.group = g.decap ();

  if (FLUMEDBG2(LABELOPS)) {
    debug_what = debug_contains (h, g);
    strbuf b2;
    b2 << "Explore (" << debug_what << ")...\n";
    flumedbg_warn(CHATTER, "Explore (%s) ...", debug_what.cstr ());
  }

  twait { idd ()->member_of (arg, &res, mkevent (st)); }

  if (!*running) {

    FLUMEDBG3(LABELOPS, CHATTER, "Completion before explore finished");

  } else if (st == FLUME_OK) {

    // Result from RPC comes with 'ynm' union descriminate, meaning
    // 'Yes/No/Maybe.'  Yes implies that yes, the handle h is a 
    // member of the group; no implies that it's not, and maybe implies
    // that it might be a member of this group's subgroups.
    if (res.ynm == YNM_YES) {
      found = true;
      *r = true;
    } else if (res.ynm == YNM_MAYBE) {
      for (size_t i = 0; i < res.subgroups->size (); i++) {
	handle_t t = (*res.subgroups)[i];

	if (FLUMEDBG2(LABELOPS)) {
	  str tmp = t.to_str ();
	  FLUMEDBG4(LABELOPS, CHATTER, "Explore (%s): new subgroup %s",
		   debug_what.cstr (), tmp.cstr ());
	}

	if (t.is_group ()) q->enqueue (t);
      }
    }
  } else {
    warn << "idd::member_of failed: " << status2str (st) << "\n";
  }

  FLUMEDBG4(LABELOPS, CHATTER, "Explore (%s) => %d",
	   debug_what.cstr (), found);

  ev->trigger ();
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::can_search (handle_t g, cbb cb, ptr<eval::ctx_t> ctx)
{
  tvars {
    labelset_t ls;
    bool rc;
    flume_status_t stat;
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  twait { lookup_labels (g, &ls, mkevent (stat)); }
  if (stat != FLUME_OK) {
    rc = false;
  } else {

    bool filtered = false;

    // First try without the filter
    rc = (ls <= *_c_labelset);
    if (!rc) {
      // after failure, try with the filter.
      if (_c_filterset) {

	if (!_c_filterset->apply (&ls)) {
	  if (ctx) {
	    // XXX - why FLUME_OK here?
	    ctx->error (FLUME_OK,
			"Internal failure in applying filterset to group");
	  }
	} else {
	  rc = (ls <= *_c_labelset);
	  filtered = true;
	}
      }
    }
      
    if (ctx && !rc) {
      ctx->error (FLUME_OK,
		  "Cannot search group ",
		  g,
		  " since this process's label ",
		  _c_labelset,
		  " does not dominate the group's ",
		  filtered ? "(filtered) " : "", "label",
		  ls);
    }
  }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::can_write (handle_t g, cbb cb, ptr<eval::ctx_t> ctx)
{
  tvars {
    labelset_t ls;
    bool rc;
    flume_status_t stat;
    int irc;
    ptr<perproc_handlemgr_t> hold;
  }

  hold = mkref (this);

  twait { lookup_labels (g, &ls, mkevent (stat)); }
  if (stat != FLUME_OK) {
    rc = false;
  } else if (!(*_c_labelset <= ls)) {
    if (ctx)
      ctx->error ("Cannot write to object; process's labelset ",
		  _c_labelset,
		  " must dominate the object's ", ls);
    rc = false;
  } else {
    twait { cap_intersects (ls.O (), _c_labelset->O (), mkevent (irc), ctx); }
    rc = (irc == 1);
  }
  cb->trigger (rc);
}
    
//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::lookup_labels (handle_t g, labelset_t *out,
				    flume_status_cb_t cb)
{
  tvars {
    idd_get_group_labels_res_t res;
    x_handle_t arg;
    clnt_stat err;
    flume_status_t stat (FLUME_OK);
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  if (!g.is_group ()) {
    stat = FLUME_EGROUP;
  } else {
    g.to_xdr (&arg);
    
    twait { 
      idd ()->conn ()->call (IDD_GET_GROUP_LABELS, &arg, &res, 
			     mkevent (err)); 
    }
    if (err) {
      warn << "RPC error with IDD: " << err << "\n";
      stat = FLUME_ERPC;
    } else {
      stat = res.status;
      if (stat == FLUME_OK) {
	twait { idd ()->thaw (res.labels, out, mkevent (stat)); }
      }
      if (stat != FLUME_OK) {
	warn << "Failed to lookup labels for group: "
	     << g.to_str () << "; rc=" << int (stat) << "\n";
      }
    }
  }
  cb->trigger (stat);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::contains (handle_t g, capability_t h, evb_t cb,
			       ptr<eval::ctx_t> ctx)
{
  tvars {
    bool found (false);
    bfsq_t<handle_t> q;
    rendezvous_t<bool> rv (__FILE__, __LINE__);
    bool cancelled (false);
    bool cs (false);
    int nout (0);
    str debug_what;
    ptr<perproc_handlemgr_t> hold;
    ptr<bool> running (New refcounted<bool> (true));
  }
  hold = mkref (this);

  if (FLUMEDBG2(LABELOPS)) {
    debug_what = debug_contains (h, g);
    flumedbg_warn (CHATTER, "contains(%s)...", debug_what.cstr ());
  }

  cb->set_cancel_notifier (mkevent (rv, true));

  if (!g.is_group ()) {
    warn ("contains() called on a non-group: 0x%" PRIx64 "\n", g.value ());

  } else {

    twait { can_search (g, mkevent (cs), ctx); }

    if (cs) {
      q.enqueue (g);
      
      // Note there will always be one trigger outstanding since we 
      // can be cancelled.
      while (!found && !cancelled && (nout > 0 || q.size ())) {
	while (q.size () && !found) {
	  explore (h, &q, &found, running, mkevent (rv,false));
	  nout ++;
	}
	twait (rv, cancelled);
	if (!cancelled) {
	  nout--;
	  assert (nout >= 0);
	}
      }
    } else {
      FLUMEDBG4(LABELOPS, CHATTER, 
	       "contains(%s): Cannot search", debug_what.cstr ());
    }
  }
  
  FLUMEDBG4(LABELOPS, CHATTER, 
	   "contains(%s) => %d\n", debug_what.cstr (), found);
  
  cb->trigger (found);

  *running = false;
  rv.cancel ();
}

//-----------------------------------------------------------------------
  
tamed void
mutating_perproc_handlemgr_t::group_union_in (handle_t g, 
					      const x_handlevec_t *x, 
					      flume_status_cb_t cb, 
					      ptr<eval::ctx_t> ctx)
{
  tvars {
    bool cw;
    flume_status_t res;
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  twait { can_write (g, mkevent (cw), ctx); }
  if (!cw) {
    res = FLUME_EPERM;
  } else {
    twait { group_union_in_unsafe (g, x, mkevent (res), ctx); }
  }
  cb->trigger (res);
}

//-----------------------------------------------------------------------

tamed void
mutating_perproc_handlemgr_t::group_union_in_unsafe (handle_t m, 
						     const x_handlevec_t *x,
						     flume_status_cb_t cb,
						     ptr<eval::ctx_t> ctx)
{
  tvars {
    flume_status_t res;
    operate_on_group_arg_t arg;
    clnt_stat err;
    capset_t cs (*x);
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  if (!cs.is_valid ()) {
    res = FLUME_EINVAL;
    warn << "Given capability set contains non-capabilities.\n";
  } else if (!cs.is_persistent ()) {
    res = FLUME_EPERSISTENCE;
    warn << "Given capability set contains temporary handles.\n";
  } else {
    arg.group = m;
    arg.op = GROUP_OPERATION_ADD;
    arg.terms = *x;
    twait { 
      idd ()->conn ()->call (IDD_OPERATE_ON_GROUP, &arg, &res, 
			     mkevent (err)); 
    }
    if (err) {
      warn << "RPC error talking to IDD: " << err;
      res = FLUME_ERPC;
    } else if (res == FLUME_EPERM) {
      if (ctx)
	ctx->error ("IDD failure to operate on the given group.");
    }
  }
  cb->trigger (res);

}

//-----------------------------------------------------------------------

  
/**
 * Check and see if the handle h is a member of any of the groups
 * in the given vector; if yes, trigger with a true; if not or if cancelled,
 * trigger with a false;
 */
tamed void
perproc_handlemgr_t::check_for_cap (capability_t h, const vec<handle_t> *g, 
				    evb_t cb, ptr<eval::ctx_t> ctx)
{
  tvars {
    size_t i;
    int res (0);
    rendezvous_t<int> rv;
    vec<bool> return_vals;
    int j;
    size_t n_out (0);
    ptr<perproc_handlemgr_t> hold;
  }

  hold = mkref (this);
  cb->set_cancel_notifier ( mkevent (rv,-1) );
  
  return_vals.setsize (g->size ());
  
  for (i = 0; i < g->size (); i++) {
    contains ((*g)[i], h, mkevent (rv, int (i), return_vals[i]), ctx);
    n_out ++;
  }
  
  while (n_out > 0 && res == 0) {
    twait (rv, j);
    if (j >= 0) {
      if (return_vals[j]) res = 1;
      n_out --;
    } else {
      res = -1;
    }
  }

  cb->trigger (res == 1);

  rv.cancel ();
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::subset_of_0 (const label_t *lhs, 
				  setcmp_type_t t, cbi cb,
				  ptr<eval::ctx_t> ctx)
{
  tvars {
    const label_t *v[1];
    int rc;
  }
  v[0] = NULL;
  twait { subset_of (lhs, v, t, mkevent (rc), ctx); }
  cb->trigger (rc);
}


//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::subset_of_1 (const label_t *lhs, 
				  const label_t *rhs, 
				  setcmp_type_t tmp, cbi cb,
				  ptr<eval::ctx_t> ctx)
{
  tvars {
    const label_t *v[2];
    int rc;
  }
  v[0] = rhs;
  v[1] = NULL;
  twait { subset_of (lhs, v, tmp, mkevent (rc), ctx); }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::subset_of_2 (const label_t *l, const label_t *r1, 
				  const label_t *r2, setcmp_type_t tp, cbi cb,
				  ptr<eval::ctx_t> ctx)
{
  tvars {
    const label_t *v[3];
    int rc;
  }
  v[0] = r2;
  v[1] = r1;
  v[2] = NULL;
  pivot_nulls (v, v + 1);
  
  twait { subset_of (l, v, tp, mkevent (rc), ctx); }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::subset_of_3 (const label_t *l,
				  const label_t *r1, const label_t *r2, 
				  const label_t *r3, setcmp_type_t tp, cbi cb,
				  ptr<eval::ctx_t> ctx)
{
  tvars {
    const label_t *v[4];
    int rc;
  }
  v[0] = r1;
  v[1] = r2;
  v[2] = r3;
  v[3] = NULL;
  pivot_nulls (v, v + 2);
  twait { subset_of (l, v, tp, mkevent (rc), ctx); }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::contained_in (handle_t h, const label_t *r, cbi cb,
				   ptr<eval::ctx_t> ctx)
{
  tvars {
    label_t lhs;
    const label_t *rhs[2];
    int rc;
  }
  lhs.insert (h);
  rhs[0] = r;
  rhs[1]= NULL;

  twait { subset_of (&lhs, rhs, COMPARE_NONE, mkevent (rc), ctx); }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::cap_intersects (const capset_t *x, const capset_t *y,
				     cbi cb, ptr<eval::ctx_t> ctx)
{
  tvars {
    int rc;
  }
  if (!x || x->is_empty ()) {
    rc = 1;
  } else {
    twait { intersects (x, y, mkevent (rc), ctx); }
  }
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

// Check if x intersects y at all.
tamed void
perproc_handlemgr_t::intersects (const label_t *x, const label_t *y, cbi cb,
				 ptr<eval::ctx_t> ctx)
{
  tvars {
    hset_iterator_t it (x->map ());
    const handle_t *h;
    int rc (0);
    int lrc;
  }

  while ((h = it.next ()) && rc == 0) {
    twait { contained_in (*h, y, mkevent (lrc), ctx); }
    if (lrc == 1) {
      rc = 1;
    }
  }

  intersects_debug (x, y, rc);

  cb->trigger (rc);
}

//-----------------------------------------------------------------------

/*
 * Returns: 0 if failure, and 1 if success
 */
tamed void
perproc_handlemgr_t::subset_of (const label_t *lhs, const label_t **rhs, 
				setcmp_type_t typ, cbi cb, 
				ptr<eval::ctx_t> ctx)
{
  tvars {
    vec<handle_t> groups;
    vec<capability_t> misses;
    vec<bool> rets;
    size_t i;
    rendezvous_t<size_t> rv;
    int res (1);
    const label_t **rhp;
    handle_prefix_t def_bits;
    handle_prefix_t cap_bits;
    bool cap_domain (false);
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  subset_of_debug (lhs, rhs, typ);

  switch (typ) {
  case COMPARE_ADD:
    def_bits = HANDLE_OPT_DEFAULT_ADD;
    cap_bits = CAPABILITY_ADD;
    break;
  case COMPARE_SUBTRACT:
    def_bits = HANDLE_OPT_DEFAULT_SUBTRACT;
    cap_bits = CAPABILITY_SUBTRACT;
    break;
  default:
    def_bits = 0;
    cap_bits = 0;
    cap_domain = true;
    break;
  }
  
  if (lhs) {
    hset_iterator_t i (lhs->map ());
    const handle_t *k;
    while ((k = i.next ())) {

      // check if it's removable / addable by default
      // If so, then we found it; if not, they we keep looking
      if (!k->is_capability () && (k->prefix () & def_bits))
	continue;
      
      // or, could be contained literally in one of the 
      // labels, or the capability to add/remove it is contained
      // in one of the RHS capability sets
      if (k->contained_in (rhs, cap_bits))
	continue;

      // If we didn't find it, then we're just looking for a capability
      // from here on out.  So push back the capability to look for...
      misses.push_back (capability_t (cap_bits, *k));
    }
  }
  
  if (misses.size ()) {
    for (rhp = rhs; *rhp; rhp++) {
      if (*rhp) (*rhp)->export_groups (&groups);
    }
    
    rets.setsize (misses.size ());
    
    for (i = 0; i < misses.size (); i++) {
      check_for_cap (misses[i], &groups, mkevent (rv, i, rets[i]), ctx);
    }
    
    while (rv.n_triggers_left () && res) {
      twait(rv, i);
      if (!rets[i]) res = 0;
    }
  }

  subset_of_debug_res (res);
  
  cb->trigger (res);

  rv.cancel ();
}

//-----------------------------------------------------------------------

void
global_idd_init (idd::server_handle_t *i, const str &seed)
{
  assert (i);
  global_handlemgr = New global_handlemgr_t (i, seed);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::check_add_sub_all (ptr<const label_t> l, cbi cb,
					ptr<eval::ctx_t> ctx)
{
  tvars {
    rcset_t<int> rcs (2, 1);
    int rc;
    ptr<perproc_handlemgr_t> hold;
  }
  hold = mkref (this);

  twait {
    subset_of (l, _c_labelset->O(), COMPARE_ADD, mkevent (rcs[0]), ctx); 
    subset_of (l, _c_labelset->O(), COMPARE_SUBTRACT, mkevent (rcs[1]), ctx); 
  }
  rc = rcs.project ();
  if (rc != 1) {
    const char *ops[] = { "add", "subtract" };
    for (int i = 0; i <  2; i++) {
      if (rcs[i] != 1 && ctx) {
	ctx->error ("check_add_sub_all failure; could not ", ops[i],
		    " all of ", l, " with an ownsership label of ",
		    _c_labelset->O ());
      }
    }
  }

  cb->trigger (rc);
}

//-----------------------------------------------------------------------

tamed void
perproc_handlemgr_t::check_filter (const filter_t &filter,
				   const req_privs_arg_t *rpa,
				   flume_status_cb_t cb, ptr<eval::ctx_t> ctx)
{
  tvars {
    flume_status_t st;
    handle_t h;
    capset_t c;
    label_t delta;
    rcset_t<int> rcs (2,1);
    int rc;
  }

  twait { idd ()->req_privs (rpa, mkevent (st)); }
  if (st == FLUME_OK) {
    h = rpa->handle;
    c.insert (h);
    
    filter.compute_delta (&delta, &delta);

    twait {
      subset_of (&delta, &c, COMPARE_ADD, mkevent (rcs[0]), ctx);
      subset_of (&delta, &c, COMPARE_SUBTRACT, mkevent (rcs[1]), ctx);
    }
    rc = rcs.project ();
    if (rc != 1) {
      const char *ops[] = { "add", "subtract" };
      label_t *l[] = { &delta, &delta };
      for (int i = 0; i < 2; i++) {
	if (rcs[i] != 1 && ctx) {
	  ctx->error ("check_filter: failed to ", ops[i],
		      " the handles in ", l[i],
		      " given the capabilities in ", &c);

	}
      }
      st = FLUME_EPERM;
    } else {
      st = FLUME_OK;
    }
  } else {
    st = FLUME_ECAPABILITY;
  }
  cb->trigger (st);
}
