
// -*-c++-*-
#include "async.h"
#include "crypt.h"
#include "rm.h"
#include "flume_idd_prot.h"
#include "asyncutil.h"
#include "evalctx.h"

namespace rm {


  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_freeze_label (svccb *sbp)
  {
    tvars {
      holdvar x_label_t *arg (sbp->Xtmpl getarg<x_label_t> ());
      label_t l (*arg);
      frozen_label_t out;
      freeze_label_res_t res;
      flume_status_t st;
    }

    twait { idd ()->freeze (&l, &out, mkevent (st)); }

    res.set_status (st);
    if (st != FLUME_OK) {
      str s = status2str (st);
      warn << "Error when trying to freeze label: " << s << "\n";
    } else {
      *res.frozen = out;
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_subset_of (svccb *sbp)
  {
    tvars {
      subset_of_arg_t *arg (sbp->Xtmpl getarg<subset_of_arg_t> ());
      ptr<label_t> lhs (label_t::alloc (arg->lhs));
      vec<ptr<label_t> > rhs;
      const label_t **cv;
      int i;
    }
    cv = New (const label_t *[arg->rhs.size () + 1]);
    size_t k;
    for (k = 0; k < arg->rhs.size (); k++) {
      rhs.push_back (capset_t::virtual_alloc (arg->rhs[k]));
      cv[k] = rhs[k];
    }
    cv[k] = NULL;
    
    twait { hmgr ()->subset_of (lhs, cv, arg->typ, mkevent (i)); }

    delete [] cv;

    sbp->replyref (i);
  }

  //-----------------------------------------------------------------------

  tamed void 
  proc_t::handle_thaw_label (svccb *sbp)
  {
    tvars {
      frozen_label_t *arg (sbp->Xtmpl getarg<frozen_label_t> ());
      ptr<label_t> out;
      thaw_label_res_t res;
      flume_status_t st;
    }

    twait { idd ()->thaw (arg, &out, mkevent (st)); }
    res.set_status (st);
   
    if (st != FLUME_OK) {
      str s = status2str (st);
      warn << "Error when thawing label: " << s << "\n";
    } else {
      out->to_xdr (res.thawed);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void 
  proc_t::handle_new_handle (svccb *sbp) 
  {
    tvars {
      new_handle_arg_t *arg (sbp->Xtmpl getarg<new_handle_arg_t> ());
      new_handle_res_t res;
    }
    twait { hmgr ()->new_handle (arg, &res, mkevent ()); }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_new_group (svccb *sbp)
  {
    tvars {
      new_group_arg_t *arg (sbp->Xtmpl getarg<new_group_arg_t> ());
      new_group_res_t res;
    }
    twait { hmgr ()->new_group (arg, &res, mkevent ());}
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------
  
  tamed void
  proc_t::handle_lookup_by_nickname (svccb *sbp)
  {
    tvars {
      nickname_t *nick (sbp->Xtmpl getarg<nickname_t> ());
      new_handle_res_t res;
      clnt_stat err;
    }

    twait { 
      idd ()->conn ()->call (IDD_LOOKUP_HANDLE_BY_NICKNAME,
			     nick, &res, mkevent (err));
    }
    if (err) {
      warn << "Error in RPC to IDD: " << err << "\n";
      res.set_status (FLUME_ERPC);
      *res.code = int (err);
    } 
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------   
  
  tamed void
  proc_t::handle_new_nickname (svccb *sbp)
  {
    tvars {
      new_nickname_arg_t *arg (sbp->Xtmpl getarg<new_nickname_arg_t> ());
      flume_status_t res;
      clnt_stat err;
      int rc;
    }

    // Can only make a new nickname if you can leak all of the
    // data that you currently have.
    twait { hmgr ()->subset_of (S (), O (), COMPARE_SUBTRACT, mkevent (rc)); }

    if (rc < 0) {
      res = FLUME_EPERM;
    } else {
      twait { 
	idd ()->conn ()->call (IDD_NEW_NICKNAME, arg, &res, mkevent (err)); 
      }
      if (err) {
	warn << "Error in RPC to IDD: " << err << "\n";
	res = FLUME_ERPC;
      }
    }
    sbp->replyref (res);
  }


  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_get_label (svccb *sbp)
  {
    tvars {
      get_label_arg_t *arg (sbp->Xtmpl getarg<get_label_arg_t> ());
      get_label_res_t res (FLUME_OK);
      ptr<const label_t> l;
    }

    // For now, only acquire lock when updating labels
    if (0) {
      twait { _lbund->acquire_lock (tame::lock_t::SHARED, mkevent ()); }
    }

    switch (arg->specifiers.scope) {
    case LABEL_SCOPE_PROCESS: 
      {
	switch (arg->type) {
	case LABEL_S: l = S(); break;
	case LABEL_O: l = O(); break;
	case LABEL_I: l = I(); break;
	default: break;
	}
	break;
      }
    case LABEL_SCOPE_FD:
      {
	ptr<generic_sockend_t> e = _fds[*arg->specifiers.fd];
	if (e) {
	  if (e->labelset ()) {
	    switch (arg->type) {
	    case LABEL_S: l = e->labelset ()->S() ; break;
	    case LABEL_I: l = e->labelset ()->I() ; break;
	    default: res.set_status (FLUME_UNHANDLED);
	    }
	  } else {
	    res.set_status (FLUME_ENULL);
	  }
	} else {
	  res.set_status (FLUME_ENOENT);
	}
	break;
      }
    default:
      res.set_status (FLUME_EINVAL);
      break;
    }
    if (l && res.status == FLUME_OK) 
      l->to_xdr (res.label);

    // See above
    if (0) {
      _lbund->release_lock ();
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::handle_get_labelset (svccb *sbp)
  {
    // Note, void arg
    get_labelset_res_t res (FLUME_OK);
    if (labelset()) {
      labelset ()->to_xdr (res.labelset);
    } else {
      // Should never get here...
      res.set_status (FLUME_ENOENT);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void 
  proc_t::handle_set_label (svccb *sbp)
  {
    tvars {
      flume_res_t res;
      flume_status_t s;
      set_label_arg_t *arg (sbp->Xtmpl getarg<set_label_arg_t> ());
      ptr<eval::ctx_t> ctx (eval::ctx_t::alloc ());
    }

    switch (arg->which.specifiers.scope) {
    case LABEL_SCOPE_PROCESS: 
      {
	twait { 
	  set_process_label (arg->which.type, &arg->new_label, mkevent (s), 
			     ctx, arg->force); 
	}
	break;
      }
    case LABEL_SCOPE_FD: 
      {
	twait { 
	  set_fd_label (*arg->which.specifiers.fd, arg->which.type, 
			&arg->new_label, mkevent (s));
	}
	break;
      }
    default:
      s = FLUME_UNHANDLED;
      break;
    }

    if (s != FLUME_OK && ctx->perm_error ()) {
      ctx->to_xdr (&res);
    } else {
      res.set_status (s);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_set_ambient_fs_authority (svccb *sbp)
  {
    tvars {
      set_ambient_fs_authority_arg_t *a 
	(sbp->Xtmpl getarg<set_ambient_fs_authority_arg_t> ());
      flume_status_t r;
      const x_label_t *x (NULL);
    }
    if (!a->clear) x = a->newvalue;
    
    twait { set_ambient_fs_authority (x, mkevent (r)); }
    sbp->replyref (r);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::set_process_label (label_type_t t, const x_label_t *l,
			     flume_status_cb_t cb, ptr<eval::ctx_t> ctx, 
			     bool force)
  {
    tvars {
      flume_status_t stat;
    }
    switch (t) {
    case LABEL_S: 
      {
	twait { 
	  set_process_label_2 (l, labelset ()->S_pointer (), LABEL_S, 
			       mkevent (stat), ctx, force);
	}
	break;
      }
    case LABEL_I: 
      {
	twait { 
	  set_process_label_2 (l, labelset ()->I_pointer (), LABEL_I, 
			       mkevent (stat), ctx, force);
	}
	break;
      }
    case LABEL_O: 
      {
	twait { set_process_O_label (l, mkevent (stat), force, ctx); }
	break;
      }
    default: 
      stat = FLUME_UNHANDLED;
      break;
    }

    if (stat == FLUME_EPERM && ctx && ctx->perm_error ()) {
      str s = rpc_enum_to_str (t);
      ctx->error ("In set_process_label(", s, ", ", *l, ")");
    }

    cb->trigger (stat);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_req_privs (svccb *sbp)
  {
    tvars {
      req_privs_arg_t *arg (sbp->Xtmpl getarg<req_privs_arg_t> ());
      req_privs_res_t res;
    }
    twait { idd ()->req_privs (arg, mkevent (res)); }

    if (res == FLUME_OK) {
      str s = handle_t (arg->handle).to_str();
      FLUMEDBG4(LABELOPS, CHATTER, 
	       "handle_req_privs: granting priv %s" , s.cstr ());
      O_notnull()->insert (handle_t (arg->handle));
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  static bool
  generate_token (priv_tok_t *out, priv_tok_typ_t typ)
  {
    mstr tmp (BINTOKSZ);
    rnd.getbytes (tmp.cstr (), tmp.len ());
    out->set_typ (typ);
    switch (typ) {
    case PRIV_TOK_STR:
      *out->strtok = armor32 (tmp.cstr (), tmp.len ());
      break;
    case PRIV_TOK_BINARY:
      memcpy (out->bintok->base (), tmp.cstr (), BINTOKSZ);
      break;
    default:
      return false;
    }
    return true;
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_make_login (svccb *sbp)
  {
    tvars {
      make_login_arg_t *arg (sbp->Xtmpl getarg<make_login_arg_t> ());
      idd_make_login_arg_t iarg;
      flume_status_t stat (FLUME_OK);
      make_login_res_t res (FLUME_OK);
      handle_t h (arg->handle);
      label_t tmp;
      int rc;
    }
    tmp.insert (h);

    if (!h.is_persistent ()) {
      stat = FLUME_EPERSISTENCE;
    } else if (!h.is_capability ()) {
      stat = FLUME_ECAPABILITY;
    } else {
      twait { hmgr ()->subset_of (&tmp, O(), COMPARE_NONE, mkevent (rc)); }
      if (rc <= 0) {
	ptr<eval::ctx_t> ctx = eval::ctx_t::alloc ();
	ctx->error ("The processes ownership ", O(),
		   " does not include the specified capabilities ",
		   &tmp);
	ctx->to_xdr (&res);
      } else if (!generate_token (&iarg.token, arg->desired_tok_typ)) {
	stat = FLUME_ETOKEN;
      } else {
	iarg.larg = *arg;
	twait { idd ()->make_login (iarg, mkevent (stat)); }
	res.set_status (stat);
	if (stat == FLUME_OK) {
	  *res.token = iarg.token;
	}
      }
    }
    
    if (stat != FLUME_OK && res.status != FLUME_OK) {
      res.set_status (stat);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::check_add_sub_all (ptr<const label_t> l, cbi cb, 
			     ptr<eval::ctx_t> ctx)
  {
    hmgr ()->check_add_sub_all (l, cb, ctx);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::can_switch_to (ptr<const label_t> oldl, ptr<const label_t> newl,
			 cbi cb, ptr<eval::ctx_t> ctx)
  {
    tvars {
      int rc;
    }
    twait { _lbund->can_switch_to (hmgr(), oldl, newl, mkevent (rc), ctx); }
    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  tamed void 
  proc_t::set_process_label_2 (const x_label_t *x, ptr<label_t> *out,
			       int which, flume_status_cb_t cb,
			       ptr<eval::ctx_t> ctx, bool force)
  {
    tvars {
      ptr<label_t> newl (New refcounted<label_t> (*x));
      ptr<label_t> oldl (*out);
      flume_status_t ret (FLUME_OK);
      bool ok;
    }

    if (!newl->is_flatlabel ()) {
      ret = FLUME_BAD_LABEL;
    } else {

      twait { 
	_lbund->set_proc_label (hmgr(), which, oldl, newl, mkevent (ok), ctx,
				label_change_hook (), force);
      }

      if (!ok) {
	ret = FLUME_EPERM;
      }

    }
    
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  cb_cls_t::ptr
  proc_t::label_change_hook ()
  {
    if (_parent) {
       return wrap (_parent, &child_ep_t::label_change_hook);
    } else {
      return NULL;
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::set_process_O_label (const x_label_t *x, flume_status_cb_t cb,
			       bool force, ptr<eval::ctx_t> ctx)
  {
    tvars {
      ptr<capset_t> l (New refcounted<capset_t> (*x));
      flume_status_t ret (FLUME_OK);
      bool skip_recheck;
      bool ok;
    }

    if (!l->is_valid ()) {
      ret = FLUME_ECAPABILITY;

    } else if (O () == NULL) {
      if (x->size () == 0) 
        ret = FLUME_OK;
      else
        ret = FLUME_EPERM;

    } else {
      
      skip_recheck = O()->subset_of (l);

      twait { 
	_lbund->set_proc_O_label (hmgr(), _granted_capabilities,
				  l, mkevent (ok), ctx,
				  label_change_hook (), force);
				  
      }
      if (!ok) {
	ret = FLUME_EPERM;
      } else if (!skip_recheck) {
	twait { check_ambient_fs_authority (mkevent ()); }
      }
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::take_capability (handle_t h, int flags)
  {
    _granted_capabilities->insert (h);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::check_ambient_fs_authority (cbv cb)
  {
    tvars { int rc; }
    if (_ambient_fs_authority) {
      twait { 
	hmgr ()->subset_of (_ambient_fs_authority, O(), COMPARE_NONE, 
			    mkevent (rc)); 
      }
      if (rc <= 0)
	_ambient_fs_authority->clear ();
    }
    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  void
  proc_t::handle_setepopt (svccb *sbp)
  {
    flume_setepopt_arg_t *arg = sbp->Xtmpl getarg<flume_setepopt_arg_t> ();
    flume_status_t ret;
    ptr<generic_sockend_t> s;
    if (!(s = _fds[arg->fd])) {
      ret = FLUME_ENOENT;
    } else {
      switch (arg->opt.typ) {
      case FLUME_EP_OPT_STRICT:
      case FLUME_EP_OPT_FIX:
	if (!s->label_is_mutable ()) {
	  warn ("Label on socket is not mutable: %p\n", (generic_sockend_t *)s);
	  ret = FLUME_EINVAL;
	} else {
	  bool strict;
	  if (arg->opt.typ == FLUME_EP_OPT_FIX)  {
	    strict = true;
	    s->fix ();
	  } else {
	    strict = *arg->opt.strict;
	  }
	  s->set_strict (strict);
	  ret = FLUME_OK;
	}
        break;
      default:
	ret = FLUME_UNHANDLED;
      }
    }
    sbp->replyref (ret);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::set_fd_label (int fd, label_type_t t, const x_label_t *x,
			flume_status_cb_t cb) 
  {
    tvars {
      flume_status_t ret;
      ptr<generic_sockend_t> s;
      ptr<label_t> l (New refcounted<label_t> (*x));
    }
    
    if (!l->is_flatlabel ())
      ret = FLUME_BAD_LABEL;
    else if (!(s = _fds[fd])) {
      ret = FLUME_ENOENT;
    } else if (!s->label_is_mutable ()) {
      warn ("Label on socket is not mutable: %p\n", (generic_sockend_t *)s);
      ret = FLUME_EINVAL;
    } else {
      twait { s->set_label (t, l, mkevent (ret)); }
    }

    cb->trigger (ret);
  }
 
  //-----------------------------------------------------------------------

  bool 
  proc_t::owns_capabilities (const x_capability_op_set_t &x)
  {
    for (size_t i = 0; i < x.size (); i++) {

      if (!O()->contains (x[i].handle))
	return false;
    }
    return true;
  }


  //-----------------------------------------------------------------------

  void 
  proc_t::handle_send_capabilities (svccb *sbp) 
  {
    send_capabilities_arg_t *arg = 
      sbp->Xtmpl getarg<send_capabilities_arg_t> ();
    ptr<generic_sockend_t> e = _fds[arg->dest_fd];
    p2p_sockend_t *p2p;
    ptr<p2p_sockend_t> oe;
    flume_status_t res = FLUME_OK;
    if (!e) {
      res = FLUME_ENOENT;
    } else if (!(p2p = e->to_p2p ())) {
      res = FLUME_EINVAL;
    } else if (!(oe = p2p->other_end ())) {
      res = FLUME_ENOTCONN;
    } else if (!owns_capabilities (arg->capabilities)) {
      res = FLUME_EPERM;
    } else if (p2p->can_send_across ()) {
      oe->pass_capabilities (arg->capabilities);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::pass_capabilities (const x_capability_op_set_t &x)
  {
    for (size_t i = 0; i < x.size (); i++) {
      _caps.addops (x[i].handle, x[i].level);
    }
  }

  //-----------------------------------------------------------------------

  void 
  proc_t::handle_verify_capabilities (svccb *sbp) 
  {
    verify_capabilities_arg_t *arg = 
      sbp->Xtmpl getarg<verify_capabilities_arg_t> ();
    ptr<generic_sockend_t> e = _fds[arg->fd];
    p2p_sockend_t *p2p;
    verify_capabilities_res_t res (FLUME_OK);
    if (!e) {
      res.set_status (FLUME_ENOENT);
    } else if (!(p2p = e->to_p2p ())) {
      res.set_status (FLUME_EINVAL);
    } else {
      p2p->verify_capabilities (this, *arg, &res);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::verify_capabilities (proc_t *proc,
				      const verify_capabilities_arg_t &x,
				      verify_capabilities_res_t *res)
  {
    int o;
    handle_t h;
    capmap_t tmp;

    for (size_t i = 0; i < x.caps.size (); i++) {
      verify_capability (proc, x.caps[i].handle, x.caps[i].level, &tmp);
    }
    if (x.ops_on_all) {
      for (bool c = _caps.start (&h, &o); c; c = _caps.next (&h, &o)) {
	verify_capability (proc, h, x.ops_on_all, &tmp);
      }
    }
    for (bool c = tmp.start (&h, &o); c; c = tmp.next (&h, &o)) {
      x_capability_op_t op;
      op.handle = h;
      op.level = capability_flag_t (o);
      res->results->push_back (op);
    }
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::verify_capability (proc_t *proc, handle_t h, int ops, 
				    capmap_t *out)
  {
    int *tmp = _caps[h];
    int res = 0;
    if (tmp) {
      int v = *tmp;

      if ((ops & CAPABILITY_VERIFY) &&
	  (v & (CAPABILITY_GRANT | CAPABILITY_SHOW)))
	res |= CAPABILITY_VERIFY;

      if  ((ops & CAPABILITY_TAKE) && (v & CAPABILITY_GRANT)) {
	res |= CAPABILITY_TAKE;
	proc->take_capability (h, v);
      }

      if (ops & CAPABILITY_CLEAN) {
	res |= CAPABILITY_CLEAN;
	_caps.remove(h);
      }
    }
    out->addops (h, res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_stat_group (svccb *sbp)
  {
    tvars {
      holdvar group_stat_arg_t *a (sbp->Xtmpl getarg<group_stat_arg_t> ());
      group_stat_res_t res;
      labelset_t ls;
      flume_status_t stat;
      handle_t h (a->group);
    }

    twait { hmgr ()->lookup_labels (h, &ls, mkevent (stat)); }
    res.set_status (stat);
    if (stat == FLUME_OK) {
      ls.to_xdr (res.ls);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void 
  proc_t::handle_operate_on_group (svccb *sbp)
  {
    tvars {
      flume_res_t res (FLUME_OK);
      flume_status_t stat (FLUME_OK);
      operate_on_group_arg_t *a;
      ptr<eval::ctx_t> ctx (eval::ctx_t::alloc ());
    }

    a = sbp->Xtmpl getarg<operate_on_group_arg_t> ();

    switch (a->op) {
    case GROUP_OPERATION_ADD:
      {
	twait { group_addition (a->group, &a->terms, mkevent (stat), ctx); }
	if (stat != FLUME_OK && ctx->perm_error ()) {
	  ctx->to_xdr (&res);
	}
	break;
      }
    case GROUP_OPERATION_SUBTRACT:
      stat = group_subtraction (a->group, a->terms);
      break;
    default:
      stat = FLUME_UNHANDLED;
      break;
    }
    if (stat != FLUME_OK && res.status == FLUME_OK) {
      res.set_status (stat);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  flume_status_t
  proc_t::group_subtraction (handle_t g, const x_label_t &terms)
  {
    return FLUME_UNHANDLED;
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::group_addition (handle_t h, const x_label_t *terms, 
			  flume_status_cb_t cb, ptr<eval::ctx_t> ctx)
  {
    tvars {
      flume_status_t ret (FLUME_OK);
      ptr<capset_t> cs (New refcounted<capset_t> (*terms));
    }

    if (!h.is_group () || h.is_capability ()) {
      ret = FLUME_EHANDLE;
    } else if (!cs->is_valid ()) {
      ret = FLUME_ECAPABILITY;
    } else if (!O()->superset_of (*terms)) {
      ctx->error ("Ownership check failed; terms added in ",
		  *terms, 
		  " ought to be contained in the process's "
		  "ownership label ", 
		  O());
      ret = FLUME_EPERM;
    } else {
      twait { hmgr ()->group_union_in (h, terms, mkevent (ret), ctx); }
    }
    
    cb->trigger (ret);
  }
  
  //-----------------------------------------------------------------------

  tamed void
  proc_t::set_ambient_fs_authority (const x_label_t *x, flume_status_cb_t cb)
  {
    tvars {
      flume_status_t res (FLUME_OK);
      ptr<capset_t> l;
      int rc;
    }
    
    if (!x) {
      _ambient_fs_authority = NULL;
    } else {
      l = New refcounted<capset_t> (*x);

      twait { hmgr ()->subset_of (l, O(), COMPARE_NONE, mkevent (rc)); }

      if (rc > 0) {
	_ambient_fs_authority = l;
      } else {
	res = FLUME_EPERM;
      }
    }
    cb->trigger (res);
  }

  //-----------------------------------------------------------------------

  //
  // check is this process is allowed to spawn the process with the
  // given label.
  //
  tamed void
  proc_t::can_spawn (ptr<const labelset_t> ls, spawn_res_t *res, cbv cb)
  {
    tvars {
      int rc_S, rc_I, rc_O;
    }

    twait {
      can_switch_to (S(), ls->S(), mkevent (rc_S));
      can_switch_to (I(), ls->I(), mkevent (rc_I));
      hmgr()->subset_of (ls->O(), O(), _granted_capabilities,
			 COMPARE_NONE, mkevent (rc_O));
    }

    // XXX need better error reporting 
    if (rc_S != 1 || rc_I != 1 || rc_O != 1) {
      res->set_status (FLUME_EPERM);
    } else {
      res->set_status (FLUME_OK);
    }

    cb->trigger ();
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_labelset_to_filename (svccb *sbp)
  {
    tvars {
      holdvar x_labelset_t *arg (sbp->Xtmpl getarg<x_labelset_t> ());
      ptr<labelset_t> ls (New refcounted<labelset_t> (*arg));
      file_res_t res;
      str tmp;
    }
    
    twait { idd ()->labelset2str (ls, mkevent (tmp)); }
    if (!tmp) {
      res.set_status (FLUME_EPERSISTENCE);
    } else {
      res.set_status (FLUME_PATH_OK);
      *res.path = tmp;
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_filename_to_labelset (svccb *sbp)
  {
    tvars {
      str2labelset_arg_t *arg (sbp->Xtmpl getarg<str2labelset_arg_t> ());
      flume_status_t stat (FLUME_OK);
      str2labelset_res_t res;
      labelset_t lab;
    }

    twait { idd ()->str2labelset (arg->s, &lab, mkevent (stat)); }
    if (stat != FLUME_OK) {
      res.set_status (FLUME_ENOENT);
    } else {
      lab.to_xdr (res.labelset);
    }
    sbp->replyref (res);
  }
}
