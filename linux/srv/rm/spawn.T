// -*-c++-*-

#include "async.h"
#include "crypt.h"
#include "arpc.h"
#include "flume_prot.h"
#include "rm.h"
#include "systrace_policy.h"
#include "flume_idd_prot.h"
#include "spawnutil.h"
#include "rctailq.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

namespace rm {

  //-----------------------------------------------------------------------

  static ihash<handle_t, parent_ep_t, &parent_ep_t::_child_pid, 
	       &parent_ep_t::_hlnk> _global_exit_eps;

  static void insert_exit_ep (parent_ep_t *p) 
  { 
    _global_exit_eps.insert (p); 
  }
  static void remove_exit_ep (parent_ep_t *p) 
  { 
    _global_exit_eps.remove (p); 
  }

  static ptr<parent_ep_t> lookup_exit_ep (handle_t h)
  {
    parent_ep_t *p;
    ptr<parent_ep_t> ret;
    if ((p = _global_exit_eps[h])) { ret = mkref (p); }
    return ret;
  }

  //-----------------------------------------------------------------------

  ptr<parent_ep_t>
  parent_ep_t::alloc (proc_t *parent)
  {
    ptr<parent_ep_t> ret = New refcounted<parent_ep_t> (parent);
    return ret;
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_spawn (svccb *sbp)
  {
    tvars {
      spawn_arg_t *arg (sbp->Xtmpl getarg<spawn_arg_t> ());
      ptr<labelset_t> chls; 
      spawn_res_t res;
      bool ok (false);
      ptr<proc_t> np;
      ptr<parent_ep_t> pep;
      int fd (-1);
    }

    twait { _hs_make_parent_ep (*arg, &res, &pep, mkevent (ok)); }

    if (ok) {
      chls = _hs_make_child_labels (*arg, &res);
      if (!chls) ok = false;
    }

    if (ok) {
      twait { 
	_hs_make_new_child (*arg, &res, chls, pep, &fd, &np, mkevent (ok)); 
      }
    }

    if (ok) {
      twait { _hs_do_spawn (*arg, &res, np, fd, mkevent (ok)); }
    }

    if (!ok) {
      _hs_abort (np, pep, fd);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  //
  // subroutine of handle_spawn -- clean up the trash in the case of 
  // a failure.
  //

  void
  proc_t::_hs_abort (ptr<proc_t> np, ptr<parent_ep_t> pep, int fd)
  {
    // If there's an open CTL socket end, close that off.
    if (fd >= 0) {
      close (fd);
    }
    if (np && pep) {
      _children.remove (pep);
    }
  }

  //-----------------------------------------------------------------------

  //
  // subroutine of handle_spawn -- make the parent's endpoint.
  //

  tamed void
  proc_t::_hs_make_parent_ep (const spawn_arg_t &arg, spawn_res_t *res,
			      ptr<parent_ep_t> *pepp, evb_t ev)
  {
    tvars {
      ptr<parent_ep_t> pep;
      bool ok;
    }

    pep = parent_ep_t::alloc (this);

    twait { _hs_make_ep (arg.endpoint, res, pep, mkevent (ok)); }
    if (ok) *pepp = pep;
    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::_hs_make_child_ep (const spawn_arg_t &arg, spawn_res_t *res,
			     ptr<child_ep_t> *cepp, evb_t ev)
  {
    tvars {
      ptr<child_ep_t> cep;
      bool ok;
    }

    cep = child_ep_t::alloc (this);
      
    twait { _hs_make_ep (arg.ch_endpoint, res, cep, mkevent (ok));}
    cep->set_strict (true);
    if (ok) *cepp = cep;
    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::_hs_make_ep (const x_endpoint_t *xep, spawn_res_t *res,
		       ptr<proc_ep_t> ep, evb_t ev)
  {
    tvars {
      bool ok (false);
      ptr<eval::ctx_t> ctx (eval::ctx_t::alloc ());
    }
    
    // If the caller requested a change on the endpoint for the procside
    // let's make that change here.
    ep->set (xep);

    // See if it's OK to use this endpoint.  If not, we have to
    // fail the spawn operation.
    twait { ep->check_and_set_proc (lbund (), mkevent (ok), ctx); }
    if (!ok) {
      if (ctx->perm_error ()) {
	ctx->to_xdr (res);
      } else {
	res->set_status (FLUME_ERR);
      }
    }
    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------



  //-----------------------------------------------------------------------

  // Subroutine of handle_spawn -- make the child proc's labels

  ptr<labelset_t> 
  proc_t::_hs_make_child_labels (const spawn_arg_t &arg, spawn_res_t *res)
  {
    ptr<labelset_t> ret = labelset ()->deep_clone (LABEL_ALL);

    if ((arg.opts & SPAWN_SETUID)) {
      ptr<handle_t> setuid;
      if ((setuid = rm ()->setuid_h ())) {
	/* 
	 * For setuid processes, need to give it ability to read 
	 * setuid files, and to declassify that information.  We'll
	 * trust the spawner to dispose of these capabilities appropriately
	 */
	if (!ret->O()) {
	  ret->set_O (New refcounted<capset_t> ());
	}
	ret->O()->insert (capability_t (CAPABILITY_ADD, *setuid));
	ret->O()->insert (capability_t (CAPABILITY_SUBTRACT, *setuid));
      } else {
	res->set_status (FLUME_ESETUID);
	ret = NULL;
      }
    }
    return ret;
  }

  //-----------------------------------------------------------------------

  ptr<child_ep_t>
  child_ep_t::alloc (proc_t *proc)
  {
    ptr<child_ep_t> ch = New refcounted<child_ep_t> (proc);
    return ch;
  }

  //-----------------------------------------------------------------------

  child_ep_t::child_ep_t (proc_t *proc)
    : proc_ep_t (proc, proc->endpoint_name ("child")),
      _status (FLUME_CHILD_ALIVE) {}

  //-----------------------------------------------------------------------

  //
  // Fork the current proc, for the benefit of the child with the given
  // pid
  //
  ptr<proc_t>
  proc_t::fork_me (pid_t child_unxpid, ctl_t *ctl)
  {
    ptr<proc_t> np = New refcounted<proc_t> (rm(), this, true);
    np->set_pid (child_unxpid);
    ctl->set_proc (np);

    ptr<parent_ep_t> pep = parent_ep_t::alloc (this);
    assert (pep);

    // Note need to set this explicitly, since in the case of spawn(),
    // this is done later in the setup process.
    pep->set_proc (lbund ());

    ptr<child_ep_t> chep = child_ep_t::alloc (np);
    assert (chep);

    // Make appropriate pointer connections
    np->linkup (chep, pep);

    // This is also done in a fail-possible mode in the case of spawn();
    chep->set_proc (np->lbund ());

    _children.insert (pep, np->flmpid ());
    return np;
  }

  //-----------------------------------------------------------------------

  //
  // Given the process, which is a new child (either the result of 
  // a fork or a spawn), link it up with its endpoint, and link the
  // endpoints with each other.  This is called in both the fork
  // and spawn case. Other details vary.
  //
  void
  proc_t::linkup (ptr<child_ep_t> cep, ptr<parent_ep_t> pep)
  {
    cep->set_parent (pep);
    pep->set_child (cep);
    set_parent (cep);
  }

  //-----------------------------------------------------------------------

  //
  // subroutine of handle_spawn -- make the new child's endpoint and the
  // new child process.

  tamed void
  proc_t::_hs_make_new_child (const spawn_arg_t &arg, spawn_res_t *res,
			      ptr<labelset_t> chls, ptr<parent_ep_t> pep,
			      int *fdp, ptr<proc_t> *procp,
			      evb_t ev)
			      
  {
    tvars {
      ptr<proc_t> ret;
      ptr<child_ep_t> cep;
      bool ok (false);
    }

    if (!(ret = rm ()->new_proc (this, fdp))) {
      warn << "Failed to make a new proc_t structure...\n";
      res->set_status (FLUME_ERR);
    } else {

      // The only place lsw ()->set() is ever callllled!
      // Note, we need to do this before we allocate the child
      // endoint below.
      ret->lbund ()->set (chls);

      twait { ret->_hs_make_child_ep (arg, res, &cep, mkevent (ok)); }

      if (ok) {
	ret->linkup (cep, pep);

	// Insert into the children table, so that in the case of exit,
	// the right thing will happen.
	_children.insert (pep, ret->flmpid ());

	// Flag that this process was spawned via our spawner.
	ret->_spawned = true;

	FLUMEDBG4(SPAWN, CHATTER, "spawning new child: %" PRIx64 "\n", 
		  ret->flmpid ().value ());
      }
    }

    if (ok) *procp = ret;
    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  //
  // subroutine of handle_spawn -- do the actual spawn operation.
  //

  tamed void
  proc_t::_hs_do_spawn (const spawn_arg_t &arg, spawn_res_t *res,
			ptr<proc_t> np, int fd, evb_t ev)
  {

    tvars {
      spawn_i_arg_t iarg;
      spawn_i_res_t ires;
      clnt_stat err;
      ptr<spawner_t> sp;
      bool ok (false);
      bool disappeared;
    }

    if (!(sp = rm ()->spawner ())) {
      warn << "Cannot spawn without a spawner!\n";
      res->set_status (FLUME_ERR);
    } else {
     
      flmspwn::arg2arg (arg, &iarg);
      iarg.flmpid = np->flmpid ();
      if ((arg.opts & SPAWN_SETUID)) 
	rm ()->setuid_h()->to_xdr (&iarg.setuid_h);

      twait {
	sp->x ()->sendfd (fd);
	sp->cli ()->call (FLUME_SPAWN_SPAWN, &iarg, &ires, mkevent (err));
      }
      np->parent ()->spawn_returned ();
      disappeared = np->parent ()->disappeared ();
      if (err) {
	warn << "RPC error talking to spawner: " << err << "\n";
	res->set_status (FLUME_ERPC);
	*res->rpcerr = int (err);
      } else if (ires.status != FLUME_OK &&
		 (ires.status != FLUME_EPERM || !disappeared)) {

	// In the case that the error is EPERM and the process did
	// disappear, we have to pretend that everything is OK!!!
	flmspwn::res2res (ires, res);

      } else if (np->pid () >= 0 && ires.ok->pid != np->pid ()) {
	res->set_status (FLUME_ERR);
	warn ("In spawn: PID mismatch!! %d vs %d.  np %p\n", 
	      np->pid(), ires.ok->pid, static_cast<proc_t *> (np));
      } else {
	np->set_pid (ires.ok->pid);
	np->set_confined ((iarg.opts & SPAWN_CONFINED));
	res->set_status (disappeared ? FLUME_EDISAPPEARED : FLUME_OK);
	res->ok->flmpid = np->flmpid ();
	res->ok->flmpid32 = flmpid_to_flmpid32 (res->ok->flmpid);
	FLUMEDBG4(SPAWN, CHATTER, "spawned new child: %" PRIx64 " -> %d, %d\n", 
		  np->flmpid ().value (), ires.ok->pid, res->ok->flmpid32);
	ok = true;
      }
    }
    ev->trigger (ok);
  }

  //-----------------------------------------------------------------------

  void
  child_set_t::insert (ptr<parent_ep_t> p, handle_t cpid)
  {
    p->set_pid (cpid);
    _list.insert_head (p);
    p->_in_list = true;
  }

  //-----------------------------------------------------------------------

  parent_ep_t::~parent_ep_t ()
  {
    if (_pid_set) { 
      remove_exit_ep (this); 
    }
    assert (!_in_list);
    assert (!_in_exit_order);
  }

  //-----------------------------------------------------------------------

  parent_ep_t::parent_ep_t (proc_t *p) 
    : proc_ep_t (p, p->endpoint_name ("parent")),
      _pid_set (false),
      _in_exit_order (false),
      _in_list (false) {}

  //-----------------------------------------------------------------------

  void
  parent_ep_t::set_pid (handle_t h)
  {
    assert (!_pid_set);
    _child_pid = h;
    insert_exit_ep (this);
    _pid_set = true;
  }

  //-----------------------------------------------------------------------

  str 
  spawner_t::dbg_name () const
  {
    strbuf b;
    b << "spawner process (pid=" << _pid << "; prog=" << _cfg._prog << ")";
    return b;
  }

  //-----------------------------------------------------------------------

  bool
  child_ep_t::is_ready () const
  {
    return (_status & (int (FLUME_CHILD_EXITTED) | 
		       int (FLUME_CHILD_DISAPPEARED)));

  }

  //-----------------------------------------------------------------------

  void
  child_ep_t::spawn_returned ()
  {
    _status |= int (FLUME_CHILD_SPAWN_RETURNED);
  }

  //-----------------------------------------------------------------------

  tamed void
  parent_ep_t::waiton (bool hang, flume_status_cb_t cb)
  {
    tvars {
      flume_status_t stat;
      ptr<child_ep_t> ch;
    }
    ch = child ();
    if (ch->is_ready()) {
      stat = FLUME_OK;
    } else if (hang) {
      twait { _waiters.push_back (mkevent (stat)); }
    } else {
      stat = FLUME_EAGAIN;
    }
    cb->trigger (stat);
  }

  //-----------------------------------------------------------------------
  
  bool 
  parent_ep_t::belongs_to (const proc_t *p) const
  {
    return (_proc.get () == p);
  }

  //-----------------------------------------------------------------------

  void
  child_set_t::remove (ptr<parent_ep_t> p)
  {
    if (p->_in_exit_order) {
      _exit_order.remove (p);
      p->_in_exit_order = false;
    }
    if (p->_in_list) {
      _list.remove (p);
      p->_in_list = false;
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_wait (svccb *sbp)
  {
    tvars {
      flume_wait_arg_t *arg (sbp->Xtmpl getarg<flume_wait_arg_t> ());
      flume_wait_res_t res;
      flume_status_t rc (FLUME_ENOENT);
      handle_t pid;
      bool hang (!(arg->options & WNOHANG));
      ptr<parent_ep_t> pep;
    }

    if (arg->which.typ == FLUME_WAIT_ONE) {
      pid = *arg->which.flmpid;
      if ((pep = lookup_exit_ep (pid)) && pep->belongs_to (this)) {
	twait { pep->waiton (hang, mkevent (rc)); }
      } else {
	rc = FLUME_ENOENT;
      }
    } else {
      twait { _children.waitfirst (hang, mkevent (pep, rc)); }
    }

    if (pep) {
      // no longer keep this object up anymore; let it be cleaned up.
      _children.remove (pep);
    }

    if (rc == FLUME_OK) {
      assert (pep);
      ptr<child_ep_t> chep = pep->child ();
      chep->harvested ();
      res.set_status (rc);
      chep->to_xdr (res.exit);
    }

    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  child_ep_t::to_xdr (flume_exit_t *res)
  {
    pid ().to_xdr (&res->flmpid);

    if (_status & int (FLUME_CHILD_DISAPPEARED)) {
      res->exit_status.set_status (FLUME_CHILD_DISAPPEARED);
    } else if ((_status & int (FLUME_CHILD_EXITTED))) {
      res->exit_status.set_status (FLUME_CHILD_EXITTED);
      *res->exit_status.exit_code = _exit_code;
    } else {
      res->exit_status.set_status (FLUME_CHILD_ALIVE);
    }
  }

  //-----------------------------------------------------------------------

  void
  child_ep_t::harvested ()
  {
    assert (_status != FLUME_CHILD_ALIVE);
    _status |= int (FLUME_CHILD_HARVESTED);
  }

  //-----------------------------------------------------------------------

  tamed void
  child_set_t::waitfirst (bool hang, exit_ev_t ev)
  {
    tvars {
      ptr<parent_ep_t> ep;
      flume_status_t rc (FLUME_OK);
    }
    
    if ((ep = _exit_order.first ())) {
      /* noop */
    } else if (!hang) {
      rc = FLUME_EAGAIN;      
    } else {
      twait { _all_waiters.push_back (mkevent (ep, rc)); }
    }
    ev->trigger (ep, rc);
  }
  
  //-----------------------------------------------------------------------

  void
  child_ep_t::got_exit_code (int ec)
  {

    FLUMEDBG4(SPAWN, CHATTER, "got_exit_code %d for child %" PRIx64 "\n",
	      ec, pid().value ());

    if (!(_status & FLUME_CHILD_EXITTED)) {
      
      assert (!(_status & FLUME_CHILD_HARVESTED) || 
              (_status & FLUME_CHILD_DISAPPEARED));

      _exit_code = ec;
      _status |= FLUME_CHILD_EXITTED;

      // If the child has already disappeared, then we cannot relay
      // that message, and therefore just swallow the exit event.
      if (!(_status & (FLUME_CHILD_DISAPPEARED))) {
	FLUMEDBG3(SPAWN, CHATTER, " - proc is visible => exit_event\n");
	exit_event ();
      } else {
	FLUMEDBG3(SPAWN, CHATTER, 
		  " - proc isn't visible => swallowing event\n");
      }
    }
  }

  //-----------------------------------------------------------------------

  void
  rm_t::handle_exit (svccb *sbp)
  {
    spawn_i_exit_t *arg = sbp->Xtmpl getarg<spawn_i_exit_t> ();
    flume_status_t res = FLUME_OK;
    handle_t flmpid = arg->flmpid;
    int status = arg->status;
    ptr<parent_ep_t> p;
    ptr<child_ep_t> c;

    // Lookup by the flume PID of the process that just exitted.  
    // If we get anything back, it will be the parent pointer of that
    // process, which points to the parent of this process.
    p = lookup_exit_ep (flmpid);

    if (p && p->child ()) {
      
      // It could be that p->child() was set to null because this
      // process's parent has already quit.
      p->child ()->got_exit_code (status);
    } else {
      res = FLUME_ENOENT;
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::handle_get_setuid_h (svccb *sbp)
  {
    get_setuid_h_res_t res;
    if (rm ()->setuid_h ()) {
      res.set_status (FLUME_OK);
      rm ()->setuid_h ()->to_xdr (res.h);
    } else {
      res.set_status (FLUME_ENOENT);
    }
    sbp->replyref (res);
  }

  //-----------------------------------------------------------------------

  void
  rm_t::dispatch_spawn (svccb *sbp)
  {
    if (!sbp) {
      warn << "spawner gave EOF!\n";
      clear_spawner ();
      return;
    }

    FLUMEDBG4(RPC, CHATTER, "proc_t::dispatch_spawn %d\n", sbp->proc());
  
    switch (sbp->proc ()) {
    case FLUME_SPAWN_NULL: 
      sbp->replyref (0);
      break;
    case FLUME_SPAWN_EXIT:
      handle_exit (sbp);
      break;
    default:
      sbp->reject (PROC_UNAVAIL);
      break;
    }

  }

  //-----------------------------------------------------------------------

  void
  child_ep_t::label_change_hook(ptr<const labelset_t> ls)
  {

    FLUMEDBG4(LABELOPS, CHATTER, "label change hook for pid=%" PRIx64 "\n",
	      pid ().value ());

    if (!(_status & (FLUME_CHILD_DISAPPEARED|FLUME_CHILD_EXITTED)) && 
	!can_send_exit_to_parent (ls)) {

      FLUMEDBG3(LABELOPS, CHATTER, " - changing state to 'disappeared'\n");

      _status |= FLUME_CHILD_DISAPPEARED;
      exit_event ();
    }
  }

  //-----------------------------------------------------------------------

  void
  child_ep_t::exit_event ()
  {
    _parent->exit_event ();

    // Sever all ties to parent / break circularity (to help garbage 
    // collection).
    disconnect_from_parent ();
  }

  //-----------------------------------------------------------------------

  void
  child_ep_t::disconnect_from_parent ()
  {
    _pid = _parent->child_pid ();
    _parent = NULL;
  }

  //-----------------------------------------------------------------------

  handle_t
  child_ep_t::pid () const
  {
    if (_parent) return _parent->child_pid ();
    else return _pid;
  }

  //-----------------------------------------------------------------------

  void
  parent_ep_t::exit_event ()
  {
    flume_status_cb_t::ptr c;

    if (_proc) {
      _proc->exit_event (mkref (this));
    }

    while ((_waiters.size ())) {
      c = _waiters.pop_front ();
      c->trigger (FLUME_OK);
    }
    
  }
  
  //-----------------------------------------------------------------------
  
  child_set_t::~child_set_t ()
  {
    for (ptr<parent_ep_t> p = _list.first (); p; p = _list.next (p)) {

      if (p->_in_exit_order) {
	_exit_order.remove (p);
	p->_in_exit_order = false;
      }

      // Well, we're going through all elements in the list.  The better
      // be actually in-the-list by their own reckoning!
      assert (p->_in_list);

      // 1. below, _list.delete_all() with call ~parent_ep_t on each
      //    element in the list (if it has the last reference to the element).
      // 2. ~parent_ep_t calls assert (!_in_list);
      // 3. so this is a good time to clear that flag, so as not to
      //    fail assertions below (in delete_all).
      p->_in_list = false;

      // Clearing p clears out the field ptr<child_ep_t> _child
      p->clear ();
    }

    _list.delete_all ();
    
    exit_ev_t::ptr ev;
    while (_all_waiters.size ()) {
      ev = _all_waiters.pop_front ();
      ev->trigger (NULL, FLUME_ENOENT);
    }
  }
  
  //-----------------------------------------------------------------------
  
  void
  proc_t::exit_event (ptr<parent_ep_t> p)
  {
    _children.exit_event (p);
  }
  
  //-----------------------------------------------------------------------
  
  
  //
  // How to reference count parent_eps?
  //
  //   The idea is that when a child process exits, there's a chance to
  //   get rid of the corresponding parent ep right away. We can get rid
  //   of it by removing it from the child_set_t's rclist, which will
  //   decref it appropriately.
  //
  //   The other case is if noway is yet waiting for that process to
  //   exit.  In that case, need to queue to exit event (and therefore
  //   the associated ep), which happens below.  A non-refcounted pointer
  //   is added to the exit_order tailq, putting the ep in the correct
  //   order.  The EP is eventually removed and decrefed either upon
  //   a wait, or when the parent process exits.  See proc_t::handle_wait
  //   or ::~child_set_t, respectively.
  //
  void
  child_set_t::exit_event (ptr<parent_ep_t> ep)
  {
    size_t n;
    if ((n = _all_waiters.size ())) {
      for (size_t i = 0; i < n; i++) {
        exit_ev_t::ptr ev = _all_waiters.pop_front ();
        ev->trigger (ep, FLUME_OK);
      }
      // not adding it to the exit order -> it's done!
      remove (ep);
    } else {
      ep->_in_exit_order = true;
      _exit_order.insert_tail (ep);
    }
  }
  
  //-----------------------------------------------------------------------
  
  bool 
  child_ep_t::can_send_exit_to_parent (ptr<const labelset_t> proc) const
  {
    return leq (_parent, proc);
  }

  //-----------------------------------------------------------------------

  proc_ep_t::proc_ep_t (proc_t *p, const str &nm)
    : endpoint_t (endpoint_mode_t (int (EP_RW) | int (EP_MUTABLE)), nm),
      _proc (p) {}

  //-----------------------------------------------------------------------

};		
