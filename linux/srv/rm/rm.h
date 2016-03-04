// -*-c++-*-
#ifndef _RM_RM_H_
#define _RM_RM_H_

#include "flume.h"
#include "flume_ev.h"
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
#include "endpoint.h"
#include "rclist.h"
#include "rctailq.h"

namespace rm {

  enum confinement_level_t
    { CONFINE_NORMAL     = 1,
      CONFINE_LOCKDOWN   = 2 };

  bool is_ok_res (const file_res_t &res);
  int socketpair (const socketpair_arg_t *arg, int *fds);
  duplex_t invert_duplex (duplex_t i);

  class rm_t;
  class proc_t;
  class p2p_sockend_t;
  class p2s_sockend_t;

  // 
  // A generic representation of a socket end that the RM manages;
  // Each socket end on the RM side can have an S and an I label.
  //
  class generic_sockend_t : public endpoint_t {
  public:
    // This constructor is for anonymous process<->process sockets (p2p)
    generic_sockend_t (rm_t *rm, int m);


    // This constructor is for named process<->socket sockets (p2s);
    generic_sockend_t (rm_t *rm, ptr<labelset_t> ls,
		       ptr<const labelset_t> pls, ptr<const filterset_t> pfs,
		       const str &nm);

    virtual ~generic_sockend_t ();


    rm_t *rm () { return _rm; }
    const rm_t *rm () const { return _rm; }
    void relabel_server_fd (ptr<labelset_t> ls, cbb cb, CLOSURE);

    // A subroutine called by set_label(); Given then new label
    // nl, the proc label proc, and the output location *out, make
    // sure that we can set *out to nl (taking proc into account)
    // and then set it if so.
    void set_label_2 (ptr<label_t> nl, ptr<label_t> *out,
		      ptr<const label_t> proc, flume_status_cb_t cb, CLOSURE);

    // If the proc's S or I label changed, call this to potentially
    // invalidate the per-socket label.  The which flags says which
    // labels to invalite (some subset of {S,I}).
    // If changes were made, call poke_label_change. poke_label_change
    // interrupts a proxy loop, allowing the proxy loop to update its
    // internal fields on the basis of the new label configuration.
    // That is, a label change might have turned some userproc<->userproc
    // to be unidirectional, in which case the proxy loop has to turn
    // off listening in one direction.
    virtual void poke_label_change ();
    void poke_label_change_do1side ();
    virtual void changed () { poke_label_change (); }


    // Only defined in subclasses.
    virtual ptr<p2p_sockend_t> to_p2p () { return NULL; }
    virtual ptr<p2s_sockend_t> to_p2s () { return NULL; }

    // Every socket end implies a RM<->Proc socket or pipe.  The
    // RM keeps track of both FDs in this structure.  The _my_fd
    // field is an FD that the RM owns for communicating with process
    // in question.  _their_fd is what the process would writefrom/readto
    // to communicate with the RM.  The RM gets this value filled in
    // via the REGISTER_FD RPC.
    int my_fd () const { return _my_fd; }

    void set_my_fd (int i) { _my_fd = i; }

    // For debugging purposes.
    virtual str to_str () const = 0;

    // The types of events that can interrupt a listen loop or a proxy loop
    enum event_t { SOCKET_DELETE, SOCKET_SELREAD, 
		   SOCKET_SELWRITE, SOCKET_LABELCHANGE,
		   SOCKET_EOF };

    handle_t newh ();

    void orphaned ();

    virtual bool label_is_mutable () const { return false; }

  protected:
    void close_my_fd ();
    tame::lock_t _lock;

  protected:
    rm_t *_rm;

  public:
    int           _my_fd;
    handle_t      global_id () const { return _global_id; }

  protected:

    ptr<bool> _destroyed;
    handle_t      _global_id;
    cbv::ptr _call_on_orphanage;
    cbv::ptr _call_on_label_change;

  };

  // A wrapper around a ptr<generic_sockend> to break circularity.
  //
  //   proc_t -> sockend_wrp -> generic_sockend
  //
  // Also, inside proxy loop:
  //  
  //   generic_sockend -> generic_sockend
  //
  // But when the sockend_wrp goes out of scope, it will send a message
  // to the underlying generic_sockend to kill itself.
  // 
  template<class V = generic_sockend_t>
  class sockend_wrp_t : public virtual refcount {
  public:
    sockend_wrp_t (ptr<V> s) : _sock (s) {}
    ~sockend_wrp_t () { _sock->orphaned (); }
    ptr<V> sock () { return _sock; }
    ptr<const V> sock () const { return _sock; }
  private:
    ptr<V> _sock;
  };

  //
  // userproc<->unixsocket socket endpoint.
  //
  class p2s_sockend_t : public generic_sockend_t {
  public:
    ~p2s_sockend_t ();
    p2s_sockend_t (rm_t *rm, ptr<labelset_t> ls, ptr<const labelset_t> pls,
		   ptr<const filterset_t> pfs, const str &nm);

    ptr<p2s_sockend_t> to_p2s () { return mkref (this); }
    flume_status_t listen_loop (int sz, CLOSURE);
    void send_new_conn (int fd, handle_t h, CLOSURE);
    void notify_listeners (ptr<p2p_sockend_t> p, CLOSURE);
    str to_str () const;
    void set_internal_sock_fd (int i) { _internal_sock_fd = i; }

  protected:
    int _internal_sock_fd;
    bool _listening;
  };

  //
  // userproc<->userproc socket endpoint.
  //
  class p2p_sockend_t : public generic_sockend_t {
  public:
    ~p2p_sockend_t ();
    p2p_sockend_t (rm_t *rm, int m);

    void disconnect ();
    void do_disconnect ();
    void connect (ptr<p2p_sockend_t> p) { _other_end = p; }
    bool is_connected () const { return _other_end; }
    ptr<const p2p_sockend_t> other_end () const { return _other_end; }
    ptr<p2p_sockend_t> other_end () { return _other_end; }
    void proxy_loop (CLOSURE);
    void signal_eof ();
    void poke_label_change ();
    bool is_claimed () const;

    void send_new_conn (int fd);
    duplex_t duplex () const { return _duplex; }
    void set_duplex (duplex_t d) { _duplex = d; }

    void pass_capabilities (const x_capability_op_set_t &x);
    void verify_capabilities (proc_t *proc,
			      const verify_capabilities_arg_t &x,
			      verify_capabilities_res_t *res);
    ptr<p2p_sockend_t> to_p2p () { return mkref (this); }
    void claim (claim_res_t *r, ptr<proc_label_bundle_t> lbund, cbi cb, 
		CLOSURE);

    void start_proxy_loop ();
    void comm_allowed (bool *me_to_them, bool *them_to_me);
    bool can_send_across ();
    int other_side_fd () const;
    ptr<p2p_sockend_t> other_side () { return _other_end; }
    int my_fd () const { return _my_fd; }

    void fdcb_read (cbv cb);
    void clear_read ();
    void fdcb_write (cbv cb);
    void clear_write ();

    bool label_is_mutable () const { return true; }

    void set_send_to_proc (int i) { _send_to_proc.set (i); }

    str to_str () const;

    ptr<p2p_sockend_t> _other_end;

    cbv::ptr _call_on_eof;
    ptr<const labelset_t> _label_on_close;

    void wait_until_ready (evv_t ev);
    void i_am_not_yet_ready ();
    void now_i_am_ready ();

  protected:
    capmap_t _caps;
    void verify_capability (proc_t *proc, handle_t h, int ops, capmap_t *out);
    duplex_t _duplex;
    bool _wset, _rset;

    // producer/consumer Q, length 1, of an FD to send to the proc
    // who eventually claims us.
    tame::pc1_t<int> _send_to_proc;
    bool _in_proxy_loop;

    bool _is_ready;
    evv_t::ptr _ready_ev;
  };

  //-----------------------------------------------------------------------

  /*
   * Endpoints for communication between a parent and child across
   * a spawn, either during the spawn operation, or via exit/wait
   * channel when a child is dying.
   */

  class proc_ep_t : public endpoint_t {
  public:
    proc_ep_t (proc_t *p, const str &nm) ;
    virtual ~proc_ep_t () {}
  protected:
    wkref_t<proc_t> _proc;
  };

  class parent_ep_t;

  typedef event<ptr<parent_ep_t>, flume_status_t>::ref exit_ev_t;

  class child_ep_t : public proc_ep_t {
  public:
    child_ep_t (proc_t *me);
    ~child_ep_t () {}
    static ptr<child_ep_t> alloc (proc_t *proc);
    
    void set_parent (ptr<parent_ep_t> p) { _parent = p; }

    void got_exit_code (int code);
    bool is_ready () const;
    void harvested ();

    bool can_send_exit_to_parent (ptr<const labelset_t> ls) const;

    // call whenever this proc does a label change, which might cause
    // our exit status to be DISAPPEARED!
    void label_change_hook(ptr<const labelset_t> ls);

    void to_xdr (flume_exit_t *e);

    void spawn_returned ();
    void exit_event ();

    bool disappeared () const 
    { return (_status & int (FLUME_CHILD_DISAPPEARED)); }

    void disconnect_from_parent();
    handle_t pid () const;

  private:
    int                 _status;
    int                 _exit_code;

    ptr<parent_ep_t>    _parent;
    handle_t            _pid;
  };

  class parent_ep_t : public proc_ep_t {
  public:
    parent_ep_t (proc_t *me);
    ~parent_ep_t ();
    void set_child (ptr<child_ep_t> c) { _child = c; }
    
    static ptr<parent_ep_t> alloc (proc_t *proc);

    ptr<child_ep_t> child () { return _child; }
    void set_pid (handle_t h) ;
    handle_t child_pid () const { return _child_pid; }
    void exit_event ();

    bool belongs_to (const proc_t *p) const;

    // break circularity so these things can eventually be garbage-collected
    void clear () { _child = NULL; }

    bool can_kill_child () const { return (*this <= *_child); }
    void waiton (bool hang, flume_status_cb_t cb, CLOSURE);

    rclist_entry_t<parent_ep_t> _lnk;
    ihash_entry<parent_ep_t>  _hlnk;
    rctailq_entry_t<parent_ep_t> _eolnk;
    handle_t _child_pid;
    bool _pid_set;
    bool _in_exit_order;
    bool _in_list;
  private:
    vec<flume_status_cb_t::ptr> _waiters;
    ptr<child_ep_t> _child;
  };

  class child_set_t {
  public:
    child_set_t () {}
    ~child_set_t ();
    void insert (ptr<parent_ep_t> p, handle_t cpid);
    void remove (ptr<parent_ep_t> p);
    void exit_event (ptr<parent_ep_t> ep);
    void waitfirst (bool hang, exit_ev_t ev, CLOSURE);
  private:
    rclist_t<parent_ep_t, &parent_ep_t::_lnk> _list;
    rctailq_t<parent_ep_t, &parent_ep_t::_eolnk> _exit_order;
    
    vec<exit_ev_t::ptr> _all_waiters;
  };

  //-----------------------------------------------------------------------

  template<class V = generic_sockend_t>
  class sockset_t {
  public:
    sockset_t () {}
    ~sockset_t ()
    {
      _reg.deleteall ();
      _unreg.deleteall ();
    }

    ptr<V> operator[] (int i)
    {
      ptr<sockend_wrp_t<V> > *r = _reg[i];
      return (r && *r) ? (*r)->sock () : NULL;
    }

    ptr<const V> operator[] (int i) const
    {
      ptr<const sockend_wrp_t<V> > *r = _reg[i];
      return (r && *r) ? (*r)->sock () : NULL;
    }

    bool regsock (handle_t h, int fd)
    {
      ptr<sockend_wrp_t<V> > s;
      bool ret = false;
      if (_unreg.remove (h, &s)) {
	_reg.insert (fd, s);
	ret = true;
      } 
      return ret;
    }

    bool close (int fd)
    {
      ptr<sockend_wrp_t<V> > s;
      bool ret = false;
      if (_reg.remove (fd, &s)) {
	ret = true;
      }
      return ret;
    }

    bool dup (int orig, int copy)
    {
      assert (orig != copy);
      ptr<sockend_wrp_t<V> > *s = _reg[orig];
      bool ret = false;
      if (s) {
	ret = true;
	_reg.insert (copy, *s);
      }
      return ret;
    }
    
    sockset_t<V> &operator= (const sockset_t<V> &in)
    {
      _unreg = in._unreg;
      _reg = in._reg;
      return *this;
    }

    qhash_iterator_t<handle_t, ptr<sockend_wrp_t<V> > >
    mk_unreg_iterator () 
    { return qhash_iterator_t<handle_t, ptr<sockend_wrp_t<V> > > (_unreg); }

    qhash_iterator_t<int, ptr<sockend_wrp_t<V> > >
    mk_reg_iterator () 
    { return qhash_iterator_t<int, ptr<sockend_wrp_t<V> > > (_reg); }

    void newsock (ptr<V> v)
    {
      _unreg.insert (v->global_id (), New refcounted<sockend_wrp_t<V> > (v));
    }

    qhash<handle_t, ptr<sockend_wrp_t<V> > > _unreg;
    qhash<int, ptr<sockend_wrp_t<V> > > _reg;
  };

  //-----------------------------------------------------------------------

  template<class V = generic_sockend_t>
  class sockset_iterator_t {
  public:
    sockset_iterator_t (sockset_t<V> *s)
      : _i1 (s->mk_unreg_iterator ()),
	_i2 (s->mk_reg_iterator ()) {}

    ptr<V> next () 
    {
      ptr<sockend_wrp_t<V> > w;
      if (_state == 0) {
	if (!_i1.next (&w))
	  _state ++;
      }
      if (_state == 1) {
	if (!_i2.next (&w))
	  _state ++;
      }
      return w ? w->sock() : NULL;
    }

  private:
    qhash_iterator_t<handle_t, ptr<sockend_wrp_t<V> > > _i1;
    qhash_iterator_t<int, ptr<sockend_wrp_t<V> > > _i2;
    int _state;
  };

  //-----------------------------------------------------------------------

  /*
   * A ctl_t is a control socket that belongs to a process. Note that 
   * a process can have more than one.  Thus, the control sockets keep
   * the process in scope --- when the last goes out of scope, the proc
   * evaporates and is destructed.
   */
  class ctl_t {
  public:
    ctl_t (int fd, ptr<proc_t> proc = NULL);
    ~ctl_t ();

    void dispatch (svccb *sbp);
    void set_proc (ptr<proc_t> proc);
    int fd () const { return _fd; }
    ptr<asrv> srv () const { return _srv; }

  private:
    int _fd;
    ptr<proc_t> _proc;
    ptr<axprt_unix> _x;
    ptr<asrv> _srv;
  public:
    list_entry<ctl_t> _lnk;
  };

  //-----------------------------------------------------------------------

  struct proc_t : public wkrefcount_t, public virtual refcount {

    proc_t (rm_t *rm, proc_t *parent = NULL, bool clone_lbund = false);
    ~proc_t ();

    void dispatch (svccb *sbp, ptr<axprt_unix> x, ctl_t *ctl);
    void handle_subset_of (svccb *sbp, CLOSURE);
    void handle_apply_filter (svccb *sbp, CLOSURE);
    void handle_kill (svccb *sbp);
    void handle_recv_msg (svccb *sbp, CLOSURE);
    void handle_send_msg (svccb *sbp);
    void handle_get_confined (svccb *sbp);
    void handle_setepopt (svccb *sbp);
    void handle_getpid (svccb *sbp);
    void handle_get_labelset (svccb *sbp);
    void handle_get_endpoint_info (svccb *sbp);
    void handle_closed_files (svccb *sbp);
    void handle_confine_me (svccb *sbp, ctl_t *ctl);
    void handle_finish_fork (svccb *sbp, ctl_t *ctl);
    void handle_fake_confinement (svccb *sbp);
    void handle_writefile (svccb *sbp, CLOSURE);
    void handle_labelset_to_filename (svccb *sbp, CLOSURE);
    void handle_filename_to_labelset (svccb *sbp, CLOSURE);
    void handle_dup_ctl_sock (svccb *sbp, ptr<axprt_unix> x);
    void handle_random_str (svccb *sbp);
    void handle_new_handle (svccb *sbp, CLOSURE);
    void handle_set_label (svccb *sbp, CLOSURE);
    void handle_get_label (svccb *sbp, CLOSURE);
    void handle_wait (svccb *sbp, CLOSURE);
    void handle_freeze_label (svccb *sbp, CLOSURE);
    void handle_get_setuid_h (svccb *sbp);
    void handle_thaw_label (svccb *sbp, CLOSURE);
    void handle_new_group (svccb *sbp, CLOSURE);
    void handle_operate_on_group (svccb *sbp, CLOSURE);
    void handle_dup (svccb *sbp, CLOSURE);
    void handle_stat_group (svccb *sbp, CLOSURE);
    void handle_send_capabilities (svccb *sbp);
    void handle_verify_capabilities (svccb *sbp);
    void handle_open (svccb *sbp, ptr<axprt_unix> x, CLOSURE);
    void handle_unlink(svccb *sbp, CLOSURE);
    void handle_utimes (svccb *sbp, CLOSURE);
    void handle_set_ambient_fs_authority (svccb *sbp, CLOSURE);
    void handle_req_privs (svccb *sbp, CLOSURE);
    void handle_make_login (svccb *sbp, CLOSURE);
    void handle_lookup_by_nickname (svccb *sbp, CLOSURE);
    void handle_new_nickname (svccb *sbp, CLOSURE);
    void handle_stat_file (svccb *sbp, CLOSURE);
    void handle_mkdir (svccb *sbp, CLOSURE);
    void handle_unixsocket (svccb *sbp, ptr<axprt_unix> x, CLOSURE);
    void handle_register_fd (svccb *sbp, CLOSURE);
    void handle_listen (svccb *sbp, CLOSURE);
    void handle_unixconnect (svccb *sbp, ptr<axprt_unix> x, CLOSURE);
    void handle_pipe (svccb *sbp, ptr<axprt_unix> x);
    void handle_socketpair (svccb *sbp, ptr<axprt_unix> x);
    void handle_claim_fd (svccb *sbp, ptr<axprt_unix> x, CLOSURE);
    void handle_close (svccb *sbp, CLOSURE);
    void handle_rmdir (svccb *sbp, CLOSURE);
    void handle_link (svccb *sbp, CLOSURE);
    void handle_rename (svccb *sbp, CLOSURE);
    void handle_symlink (svccb *sbp, CLOSURE);
    void handle_chdir (svccb *sbp, CLOSURE);
    void handle_getcwd (svccb *sbp, CLOSURE);
    void post_fork_check ();
    void handle_spawn (svccb *sbp, CLOSURE);
    void handle_socket (svccb *sbp, ptr<axprt_unix> x, CLOSURE);
    void handle_connect (svccb *sbp, ptr<axprt_unix> x, CLOSURE);
    void handle_debug_msg (svccb *sbp);

    ptr<const label_t> S() const { return labelset ()->S(); }
    ptr<label_t> S() { return labelset ()->S(); }
    ptr<const label_t> I() const { return labelset ()->I(); }
    ptr<label_t> I() { return labelset ()->I(); }
    ptr<const capset_t> O() const { return labelset ()->O(); }
    ptr<capset_t> O() { return labelset ()->O(); }
    ptr<capset_t> O_notnull() { return labelset ()->O_notnull (); }
    ptr<const labelset_t> labelset () const { return _lbund->labelset (); }
    ptr<labelset_t> labelset () { return _lbund->labelset (); }
    ptr<const proc_label_bundle_t> lbund () const { return _lbund; }
    ptr<proc_label_bundle_t> lbund () { return _lbund; }

    ptr<mutating_perproc_handlemgr_t> hmgr ();
    idd::server_handle_t *idd ();

    rm_t *rm () { return _rm; }

    // XXX Cruft
    bool is_safe () const { return _confined; }

    void insert (ctl_t *c);
    void remove (ctl_t *r);
    ctl_t *new_ctl (int *fdp);
    int get_primary_ctl_fd () const;

    handle_t global_id () const { return _global_id; }
    handle_t flmpid () const { return global_id (); }
    pid_t pid () const { return _unix_pid; }
    pid_t flmpid32 () const { return _flmpid32; }
    void set_pid (pid_t p);

    const filterset_t &filterset () const { return *_filter_set; }
    ptr<filterset_t> filterset_p () { return _filter_set; }
    ptr<const filterset_t> filterset_p () const { return _filter_set; }

    // set the confined bit and manipulate ep_bottom
    void set_confined (bool b);

    // set a pointer to the parent; note that we have the child
    // end of this endpoint.
    void set_parent (ptr<child_ep_t> p) { _parent = p; }
    ptr<child_ep_t> parent () { return _parent; }

    // Call this whenever an exit or an exit-like event happens
    // (such as when a process disappears from view).
    void exit_event (ptr<parent_ep_t> p);

    // Make an endpoint name for an endpoint associate with this process
    str endpoint_name (const str &prefx) const;

    str to_str () const;

    // Fork me, for the benefit of the new child pid
    ptr<proc_t> fork_me (pid_t chld_pid, ctl_t *ctl);

    ptr<labelset_t> write_labelset_ep (const file_arg_t *a, bool *checkit_p);

    void linkup (ptr<child_ep_t> cep, ptr<parent_ep_t> pep);

  protected:

    //-----------------------------------------------------------------------
    // handle_spawn helper processes
    //

    void _hs_make_parent_ep (const spawn_arg_t &arg, spawn_res_t *res,
			     ptr<parent_ep_t> *pepp, evb_t ev, CLOSURE);
    void _hs_make_child_ep (const spawn_arg_t &arg, spawn_res_t *res,
			    ptr<child_ep_t> *cepp, evb_t ev, CLOSURE);
    ptr<labelset_t> _hs_make_child_labels (const spawn_arg_t &arg, 
					   spawn_res_t *res);
    void _hs_make_new_child (const spawn_arg_t &arg, spawn_res_t *res,
			     ptr<labelset_t> chld, ptr<parent_ep_t> pep,
			     int *fdp, ptr<proc_t> *procp,
			     evb_t ev, CLOSURE);
    void _hs_do_spawn (const spawn_arg_t &arg, spawn_res_t *res,
		       ptr<proc_t> np, int fd, evb_t ev, CLOSURE);
    void _hs_abort (ptr<proc_t> np, ptr<parent_ep_t> pep, int fd);
    void _hs_make_ep (const x_endpoint_t *xep, spawn_res_t *res,
		      ptr<proc_ep_t> ep, evb_t ev, CLOSURE);

    //
    //-----------------------------------------------------------------------
    
    ptr<capset_t> fix_O_label (const x_label_t *p) ;
    ptr<labelset_t> write_labelset (const file_arg_t *a);

    void read_filter (const file_arg_t *arg, file_res_t *res, cbv cb, 
		      CLOSURE);

  public:
    int       _str_fd;

    pid_t     _unix_pid;

    bool _confined;
    bool _spawned;
    bool _exit_marked;
    
    enum fork_state_t { FORK_STATE_NONE = 0,
			FORK_STATE_PIPES = 1,
			FORK_STATE_FORK = 2 };

    // These fields are only used in the middle of a fork to store the
    // child's new ctlsock, etc.
    ctl_t *_child_ctl;
    pid_t _child_pid;

    bool _saw_child_chk_ctlsock, _saw_parent_chk_ctlsock;
    svccb *_parent_checkfork_req;
    svccb *_child_checkfork_req;
    bool _safe_fork;

    void newsock (ptr<p2p_sockend_t> s);

    // the sockets that this process currently has open, or is in the process
    // of registerin.
    sockset_t<generic_sockend_t> _fds;
    sockset_t<generic_sockend_t> *fds () { return &_fds; }

    /*
     * Capabilities granted to this process
     */
    ptr<capset_t> _granted_capabilities;

    /*
     * Must be a subset of _O_label; specifies which capabilities are
     * shows to the FS on a file open. A NULL pointer here is for
     * backwards-compatibility with Unix tools,
     * and signifies ('the whole O label').
     */
    ptr<capset_t> _ambient_fs_authority;

    /*
     * this object is indexed in 4 different hash tables, depending
     * on how the lookups work
     */
    ihash_entry<proc_t> _fd_lnk, _pid_lnk, _flmpid_lnk, _flmpid32_lnk;

    void take_capability (handle_t h, int i);
    bool owns_capabilities (const x_capability_op_set_t &x);

    void can_spawn (ptr<const labelset_t> ls, spawn_res_t *res, 
		    cbv cb, CLOSURE);
    str cwd () const { return _cwd; }
    void set_cwd (const str &s) { _cwd = s; }

    void inc_open_count ();
    void dec_open_count ();
      

  protected:
    void set_process_label (label_type_t t, const x_label_t *l, 
			    flume_status_cb_t cb, 
			    ptr<eval::ctx_t> ctx,
			    bool force,
			    CLOSURE);

    void set_process_label_2 (const x_label_t *x, ptr<label_t> *out,
			      int which, flume_status_cb_t cb, 
			      ptr<eval::ctx_t> ctx,
			      bool force,
			      CLOSURE);

    cb_cls_t::ptr label_change_hook ();
    
    void can_switch_to (ptr<const label_t> oldl, ptr<const label_t> newl,
			cbi cb, ptr<eval::ctx_t> ctx = NULL, CLOSURE);

    void set_fd_label (int fd, label_type_t t, const x_label_t *l,
		       flume_status_cb_t cb, CLOSURE);
    
    void set_process_O_label (const x_label_t *l, flume_status_cb_t cb,
			      bool force, ptr<eval::ctx_t> ctx, CLOSURE);

    void check_add_sub_all (ptr<const label_t> l, cbi cb,
			    ptr<eval::ctx_t> ctx = NULL);

    void do_subset (ptr<const label_t> lhs, 
		    ptr<const label_t> rhs,
		    setcmp_type_t op, cbi cb, 
		    const char *op_s = NULL, ptr<eval::ctx_t> ctx = NULL,
		    CLOSURE);

    flume_status_t confine_and_fork (int fd, pid_t unxpid, ctl_t *ctl,
				    bool do_confine, bool do_fork);

    flume_status_t set_fd_S_label (int fd, const x_label_t &l);
    flume_status_t set_fd_I_label (int fd, const x_label_t &l);
    void set_ambient_fs_authority (const x_label_t *l, flume_status_cb_t cb,
				   CLOSURE);
    int make_uposp (pipe_res_t *pr, duplex_t dup, const socketpair_arg_t *a);
    void claim_sockend (claim_res_t *r, claim_arg_t arg, 
			cbi cb, CLOSURE);
    flume_status_t register_fd (const register_fd_arg_t &arg);

    flume_status_t group_subtraction (handle_t h, const x_label_t &terms);
    void group_addition (handle_t h, const x_label_t *terms,
			 flume_status_cb_t cb, ptr<eval::ctx_t> ctx, CLOSURE);

    void invalidate_fd_labels (int which, cbv cb, CLOSURE);
    void check_ambient_fs_authority (cbv cb, CLOSURE);

    void create_dangling_socket (handle_t *hp, open_cb_t cb, CLOSURE);
    void connect_socket (int client_fd, int rm_fd, cbb cb, CLOSURE);


    rm_t *_rm;

    str _cwd;
    ptr<mutating_perproc_handlemgr_t> _hmgr;


    // MK 5.15.07
    // This field declared 'const' means it can't change underneath us;
    // The labelset is refcounted, though, so that endpoints can hold onto 
    // it, even after the underlying proc structure goes out of scope
    // (so it's still possible to determine effective label sets).
    // We're thinking of cases in which a process has closed its control
    // socket (i.e., it exitted) but some of its sockets might still
    // be open.  In this case, communication can still continue, and
    // we must have the appropriate label set that corresponds with the
    // communication. 
    const ptr<proc_label_bundle_t> _lbund;

    // A placehold endpoint (bottom) that gets set if this process
    // can connect outside of Flume.
    ptr<endpoint_t> _ep_bottom;

  public:
    handle_t               _global_id;
    pid_t                  _flmpid32;

  protected:
    list<ctl_t, &ctl_t::_lnk> _ctls;
    
    ptr<filterset_t> _filter_set;
    int _opens_in_progress;


    // points back to the parent via some endpoints.
    ptr<child_ep_t> _parent;
    child_set_t _children;

  };

  //-----------------------------------------------------------------------

  class spawner_t {
  public:
    spawner_t (const flmspwn::cfg_t &o)
      : _cfg (o),
	_pid (-1) {}

    void launch (cbb cb, CLOSURE);
    ptr<aclnt> cli () { return _cli; }
    ptr<axprt_unix> x () { return _x; }
    str dbg_name () const;
    void launch (cbb cb, rm_t *rm, CLOSURE);
    
  private:
    flmspwn::cfg_t _cfg;
    int _pid;

    ptr<axprt_unix> _x;
    ptr<aclnt> _cli;
    ptr<asrv> _srv;
  };
  

  //-----------------------------------------------------------------------

  class fs_t {
  public:
    fs_t (const fs::cfg_t &o) : _cfg (o), _nxt_cli (0) {}
    virtual ~fs_t () {}

    struct cli_t {
      cli_t ()  : _fs (NULL), _id (0), _pid (-1) {}

      void init (fs_t *fs, size_t i);
      str dbg_name () const;

      void launch (const vec<str> &argv, char *const *env, evb_t ev, CLOSURE);
      void caught_sig (int status);
      const str &name () const { return _name; }
      ptr<aclnt> cli () { return _cli; }
      ptr<axprt_unix> x () { return _x; }

      fs_t *_fs;
      ptr<axprt_unix> _x;
      ptr<aclnt> _cli;
      size_t _id;
      pid_t _pid;
      str _name;
    };

    str mountpoint () const { return _cfg._mountpoint; }
    bool is_readonly () const { return _cfg._readonly; }
    str dbg_name (size_t i) const;
    const str root () const { return _cfg._root; }
    void set_handle_seed (const str &s) { _cfg.set_handle_seed (s); }

    cli_t *pick_cli ();

  protected:
    cli_t *next_cli ();
    fs::cfg_t _cfg;

    size_t _nxt_cli;
    vec<cli_t> _cli;

    qhash<str, time_t> _miss_cache;

  public:
    virtual void launch (const idd::server_handle_t *h, cbb cb) 
    { launch_T (h, cb); }
    virtual void op (int proc, const file_arg_fs_t *a, int opts, 
		     file_res_t *r, cbv cb) { op_T (proc,a, opts, r, cb); }
  private:
    void launch_T (const idd::server_handle_t *h, cbb cb, CLOSURE);
    void op_T (int proc, const file_arg_fs_t *a, int opts, 
	     file_res_t *r, cbv cb, CLOSURE);
    
  };

  //-----------------------------------------------------------------------

  class fs_optmz_t : public fs_t {
  public:
    fs_optmz_t (const fs::cfg_t &o) : fs_t (o) {}

    void launch (const idd::server_handle_t *h, cbb cb) 
    { fs_optmz_t::launch_T (h, cb); }

    void op (int proc, const file_arg_fs_t *a, int opts, 
	     file_res_t *r, cbv cb) 
    { fs_optmz_t::op_T (proc,a, opts, r, cb); }
  private:
    void launch_T (const idd::server_handle_t *h, cbb cb, CLOSURE);
    void op_T (int proc, const file_arg_fs_t *a, int opts, 
	     file_res_t *r, cbv cb, CLOSURE);

    bool open (const file_arg_fs_t *a, int opts, file_res_t *r);
    bool stat (const file_arg_fs_t *a, int opts, file_res_t *r);

    str mkfile (const file_arg_fs_t *a);
  };

  enum { RM_DEBUG_FAKE_CONFINEMENT = 1 };

  //-----------------------------------------------------------------------

  // This is a singleton; there should be one rm_t per flumerm process.
  class rm_t : public config_parser_t {
  public:
    rm_t ();
    ~rm_t ();

    void remove (proc_t *p);
    void insert (proc_t *p);
    void insert_unix_pid (proc_t *p);
    void remove_unix_pid (proc_t *p);
    proc_t *get_proc_by_pid (pid_t p);

    void handle_exit (svccb *sbp);

    ihash<pid_t, proc_t, &proc_t::_unix_pid, &proc_t::_pid_lnk> _procs_by_pid;
    ihash<handle_t, proc_t, &proc_t::_global_id, 
	  &proc_t::_flmpid_lnk> _procs_by_flmpid;
    ihash<pid_t, proc_t, &proc_t::_flmpid32, 
	  &proc_t::_flmpid32_lnk> _procs_by_flmpid32;

    void launch (str s, CLOSURE);

    void init_signals ();
    void caught_signal (int which);


    // FS features handled by the RM object
    void fsop (int proc, 
	       const str &cwd,
	       const file_arg_t *a, 
	       ptr<const labelset_t> ls, 
	       int opts, file_res_t *res,
	       cbv cb, 
	       const filterset_t *fs,
	       str *p_norm_p = NULL, 
	       str *root_p = NULL,
	       ptr<const labelset_t> ls_proc_creat = NULL,
	       CLOSURE);

    idd::server_handle_t *idd () { return _idd; }

    void post_to_socket_claim (ptr<p2p_sockend_t> p, int i = 0);
    ptr<p2p_sockend_t> claim_socket (handle_t h, int i = 0);


    bool can_fake_confinement () const 
    { return _debug_flags & RM_DEBUG_FAKE_CONFINEMENT; }

    ptr<proc_t> new_proc (proc_t *parent, int *fpd);

    ptr<spawner_t> spawner () { return _spawner; }

    void dispatch_spawn (svccb *sbp);
    void clear_spawner () { _spawner = NULL; }
    ptr<handle_t> setuid_h () { return _setuid_h; }

    int strfd () const { return _strfd; }

  protected:
    ptr<flume_grp_t> default_fs_group ();
    ptr<flume_grp_t> default_spawn_group ();
    ptr<flume_usr_t> default_fs_user ();
    ptr<flume_usr_t> default_spawn_user ();
    ptr<flume_grp_t> default_group (ptr<flume_grp_t> *g, const str &def, 
				   const char *what);
    ptr<flume_usr_t> default_user (ptr<flume_usr_t> *u, const str &def, 
				  const char *what);

    void add_fs (ptr<fs_t> f) { _fs.push_back (f); }
    bool parse_file (const str &f);
    bool post_config (const str &fn);
    int systrace_open ();
    void socket_accept_client ();
    void systrace_read ();

    void alloc_handle_mgr ();

    void start_systrace (cbb cb, CLOSURE);
    void start_idd (cbb cb, CLOSURE);
    void start_client (cbb cb, CLOSURE);
    void start_fileservers (cbb cb, CLOSURE);
    void start_spawner (cbb cb, CLOSURE);

    void got_fs (vec<str> v, str loc, bool *errp);
    void got_spawner (vec<str> v, str loc, bool *errp);
    void got_idd_cache_opts (vec<str> v, str loc, bool *errp);
    void got_setuid_h (vec<str> v, str loc, bool *errp);
    void got_idd (vec<str> v, str loc, bool *errp);
    bool got_generic_exec (vec<str> &s, str loc, bool *errp, ptr<argv_t> *ep);
    str flume_exec (const str &f) const;
    ptr<mounttree2::iterator_t<fs_t> > 
    mk_iterator (const str &cwd, const str &in, str *out, vec<str> *v);

    str _topdir, _socket_file, _systrace_file;
    str _def_fs_username, _def_fs_groupname;
    str _def_spawn_username, _def_spawn_groupname;
    vec<ptr<fs_t> >  _fs;
    ptr<spawner_t> _spawner;

    ptr<flume_usr_t> _def_fs_u, _def_spawn_u;
    ptr<flume_grp_t> _def_fs_g, _def_spawn_g;

    // _strfd = "SYSTRACE FD"
    int _strfd, _srvfd;
    bool _socket_open;

    mounttree2::root_t<fs_t> _tree;

    qhash<handle_t, ptr<p2p_sockend_t> > _socket_claim[2];
    
    idd::cfg_t _idd_cfg;
    idd::server_handle_t *_idd;
    str _handle_seed;
    u_int _socket_file_mode;
    int _debug_flags;
    handle_t _global_id;
    ptr<handle_t> _setuid_h;
    bool _greedy;
  };

};

extern rm::rm_t *rm_obj;

#endif /* _RM_RM_H_ */
