
// -*-c++-*-

#include "flume_prot.h"
#include "rm.h"

namespace rm {

  //-----------------------------------------------------------------------

  void
  rm_t::remove (proc_t *p)
  {
    _procs_by_flmpid.remove (p);
    if (p->pid () >= 0) {
      remove_unix_pid (p);
    }
    if (p->flmpid32 () >= 0) {
      _procs_by_flmpid32.remove (p);
    }
  }

  //-----------------------------------------------------------------------

  void
  rm_t::insert (proc_t *p)
  {
    _procs_by_flmpid.insert (p);
    
    if (p->pid () >= 0) { 
      _procs_by_pid.insert (p);
    }
    
    if (p->flmpid32 () >= 0) {
      _procs_by_flmpid32.insert (p);
    }
  }

  //-----------------------------------------------------------------------


  void
  proc_t::set_pid (pid_t p)
  {
    FLUMEDBG4(PROCESS, CHATTER, "[%d] Set_pid: %p\n", p, this);
    if (_unix_pid == p) {
      assert (rm ()->get_proc_by_pid (p) == this); 
    } else {
      if (_unix_pid >= 0) {
	FLUMEDBG4(PROCESS, ERROR, 
		 "[%p] Pid Changed from %d -> %d\n", this, _unix_pid, p);
	rm ()->remove_unix_pid (this);
      }
      _unix_pid = p;
      rm ()->insert_unix_pid (this);
    }
  }


  //-----------------------------------------------------------------------

  void
  rm_t::insert_unix_pid (proc_t *p)
  {
    assert (p->pid () >= 0);
    _procs_by_pid.insert (p);
  }

  //-----------------------------------------------------------------------
  
  void
  rm_t::remove_unix_pid (proc_t *p)
  {
    FLUMEDBG4(PROCESS, CHATTER, "[%d] Unset pid: %p\n", p->pid (), p);
    assert (p->pid () >= 0);
    _procs_by_pid.remove (p);
  }

  //-----------------------------------------------------------------------

  proc_t::~proc_t () 
  { 
    FLUMEDBG4(MEMORY, CHATTER, "[%d] Process deletion: %p", _unix_pid, this);

    rm ()->remove (this);
  }

  //-----------------------------------------------------------------------

  proc_t::proc_t (rm_t *rm, proc_t *parent, bool clone_lbund) :
    _str_fd (rm->strfd ()),
    _unix_pid (-1), 
    _confined (false),
    _spawned (false),
    _exit_marked (false),
    _child_ctl (NULL),
    _granted_capabilities (New refcounted<capset_t> ()),
    _rm (rm),
    _lbund ((clone_lbund && parent) ? 
	    parent->lbund ()->clone () :
	    New refcounted<proc_label_bundle_t> (LABEL_ALL)),
    _global_id (global_handlemgr->hfact ()->newh (HANDLE_OPT_IDENTIFIER)),
    _flmpid32 (flmpid_to_flmpid32 (_global_id)),
    _opens_in_progress (0)
  {
    _rm->insert (this);

    if (parent) {
      _filter_set = New refcounted<filterset_t> (parent->filterset ());
    } else {
      _filter_set = New refcounted<filterset_t> ();
    }
  }

  //-----------------------------------------------------------------------

  void
  proc_t::set_confined (bool c)
  {
    if (!c && !_ep_bottom) {
      _ep_bottom = endpoint_t::alloc_bottom ();
      _lbund->insert (_ep_bottom, false, true);
    } else if (c && _ep_bottom) {
      _lbund->remove (_ep_bottom);
      _ep_bottom = NULL;
    }
    _confined = c;
  }
      
  //-----------------------------------------------------------------------

  ptr<mutating_perproc_handlemgr_t> 
  proc_t::hmgr ()
  {
    if (!_hmgr) { 
      _hmgr = New refcounted<mutating_perproc_handlemgr_t> (labelset (), 
							    _filter_set);
    } else {
      // Maybe update the labelset in the handlemgr?  Depends how
      // change_label works.
    }
   
    return _hmgr;
  }

  //-----------------------------------------------------------------------

  idd::server_handle_t *proc_t::idd () { return _rm->idd (); }

  //-----------------------------------------------------------------------

  int
  socketpair (const socketpair_arg_t *a, int *fds)
  {
    return ::socketpair (a->domain, a->type, a->protocol, fds);
  }

  //-----------------------------------------------------------------------

  duplex_t
  invert_duplex (duplex_t d)
  {
    duplex_t out = DUPLEX_NONE;
    if (int (d) & DUPLEX_ME_TO_THEM) 
      out = duplex_t (int (out) | DUPLEX_THEM_TO_ME);
    if (int (d) & DUPLEX_THEM_TO_ME) 
      out = duplex_t (int (out) | DUPLEX_ME_TO_THEM);
    return out;
  }

  //-----------------------------------------------------------------------

  ctl_t::ctl_t (int fd, ptr<proc_t> proc)
    : _fd (fd),
      _x (axprt_unix::alloc (fd, flume_ps)),
      _srv (asrv::alloc (_x, flume_prog_1, 
			 wrap (this, &ctl_t::dispatch)))
  {

    // XXX debug
    // warn ("New ctl fd (%p,%d)\n", this, fd);

#ifndef __linux__
    flmsockopt (fd);
#endif

    set_proc (proc);
  }

  //-----------------------------------------------------------------------

  ctl_t::~ctl_t ()
  {

    FLUMEDBG4(MEMORY, CHATTER, "[%p] CTL deletion on Proc %p", this,
	     static_cast<proc_t *> (_proc));

    if (_fd) {
      close (_fd);
      _x = NULL;
      _srv = NULL;
      _fd = -1;
    }

    if (_proc)
      _proc->remove (this);
  }

  //-----------------------------------------------------------------------

  void
  ctl_t::set_proc (ptr<proc_t> proc)
  {
    if (_proc) {
      _proc->remove (this);
    }
    _proc = proc;
    _proc->insert (this);
  }


  //-----------------------------------------------------------------------

  void
  ctl_t::dispatch (svccb *sbp)
  {
    if (!sbp) {
      delete (this);
      return;
    }
    _proc->dispatch (sbp, _x, this);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::insert (ctl_t *c)
  {
    _ctls.insert_head (c);
  }

  //-----------------------------------------------------------------------

  void
  proc_t::remove (ctl_t *c)
  {
    _ctls.remove (c);
  }

  //-----------------------------------------------------------------------

  ctl_t *
  proc_t::new_ctl (int *fdp)
  {
    int socks[2];
    ctl_t *ctl = NULL;
    int theirs = -1;
    if (::socketpair (AF_UNIX, SOCK_STREAM, 0, socks) < 0) {
      warn ("socketpair(2) failed: %m\n");
    } else {
      int mine = socks[0];
      theirs = socks[1];
      make_async (mine);
      ctl = New ctl_t (mine, mkref (this));
      *fdp = theirs;
    }
    return ctl;
  }

  //-----------------------------------------------------------------------

  int
  proc_t::get_primary_ctl_fd () const
  {
    if (_ctls.first) {
      return _ctls.first->fd ();
    }
    return -1;
  }

  //-----------------------------------------------------------------------
  
  str
  proc_t::to_str () const 
  {
    str pid_str = _global_id.to_str ();
    strbuf b ("pid=[%x,%s]", _flmpid32, pid_str.cstr ());
    return b;

  }

  //-----------------------------------------------------------------------

  str
  proc_t::endpoint_name (const str &prfx) const
  {
    str p = to_str ();
    strbuf b ("%s %s EP", p.cstr (), prfx.cstr ());
    return b;
  }

  //-----------------------------------------------------------------------

};
