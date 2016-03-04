
// -*-c++-*-

#include "async.h"
#include "crypt.h"
#include "arpc.h"
#include "flume_prot.h"
#include "rm.h"
#include "systrace_policy.h"
#include "flume_idd_prot.h"

#ifdef __linux__
#include <sys/prctl.h>
#endif

namespace rm {

  namespace fsop {

    //=======================================================================

    class obj_t {
    public:

      obj_t (proc_t *p, svccb *sbp, ptr<axprt_unix> x = NULL)
	: _proc (mkref (p)),
	  _sbp (sbp),
	  _x (x),
	  _arg (sbp->Xtmpl getarg<file_arg_t> ()),
	  _fs_opts (0), 
	  _ep_mode (EP_READ),
	  _fd (-1), 
	  _sendfd (-1) {}
      
      virtual ~obj_t () {}
      
    public:
      void go (evv_t ev, CLOSURE);
      
    protected:
      void reply ();
      void run (evv_t ev, CLOSURE);
      str path () const { return _path; }
      str unjailed () const { return _unjailed; }
      ptr<endpoint_t> endpoint () const { return _ep; }
      
      virtual int fs_opcode () const = 0;
      virtual void init_fs_opts () {}
      virtual bool do_creat () const { return false; }
      virtual ptr<endpoint_t> allocate_ep (ptr<labelset_t> ls);
      virtual bool is_socket () const { return false; }
      virtual bool keep_endpoint () const { return false; }
      virtual void success_result () = 0;
      
      virtual const char *opname () const = 0;
      void process_result (evv_t ev, CLOSURE);
      
    protected:
      ptr<proc_t> _proc;
      svccb *_sbp;
      ptr<axprt_unix> _x;
      const file_arg_t *_arg;
      file_res_t _res;
      str _path, _unjailed;
      ptr<endpoint_t> _ep;
      int _fs_opts;
      endpoint_mode_t _ep_mode;
      int _fd;
      int _sendfd;
    };
    
    //=======================================================================

    class chdir_t : public obj_t {
    public:
      chdir_t (proc_t *p, svccb *sbp) : obj_t (p, sbp, NULL) {}
      int fs_opcode () const { return FLUME_FS_OPEN; }
      const char *opname () const { return "chdir"; }
      void success_result ();

    };

    //=======================================================================
    
    class open_t : public obj_t {
    public:
      open_t (proc_t *p, svccb *sbp, ptr<axprt_unix> x)
	: obj_t (p, sbp, x) {}
      
      void init_fs_opts ()
      {
	if (flags_for_write (_arg->c_args.flags)) {
	  _fs_opts |= (FS_OP_CREATE|FS_OP_WRITE);
	  _ep_mode = EP_RW;
	}
	_fs_opts |= FS_OP_FDPASS;
      }
      
      int fs_opcode () const { return FLUME_FS_OPEN; }
      bool keep_endpoint () const { return true; }
      
      bool do_creat () const { return (_arg->c_args.flags | O_CREAT); }
      const char *opname () const { return "open"; }
      void success_result ();
      
    };
    
    //=======================================================================

    class unixsock_t : public obj_t {
    public:
      unixsock_t (proc_t *p, svccb *sbp, ptr<axprt_unix> x) 
	: obj_t (p, sbp, x) {}
      
      int fs_opcode () const { return FLUME_FS_UNIXSOCKET; }
      void init_fs_opts ()
      {
	_fs_opts = FS_OP_FDPASS | FS_OP_CREATE | FS_OP_WRITE;
	_ep_mode = EP_RW;
      }
      ptr<endpoint_t> allocate_ep (ptr<labelset_t> ls);
      bool do_creat () const { return true; }
      bool is_socket () const { return true; }
      bool keep_endpoint () const { return true; }
      const char *opname () const { return "unixsocket"; }
      void success_result ();
    private:
      ptr<p2s_sockend_t> _p2s;
    };
    
    //=======================================================================

  };
  
  //-----------------------------------------------------------------------

  ptr<endpoint_t>
  fsop::obj_t::allocate_ep (ptr<labelset_t> ls)
  {
    _ep = New refcounted<file_endpoint_t> (ls, _ep_mode,
					   _proc->lbund ()->labelset (),
					   _proc->filterset_p (),
					   _arg->c_args.path.cstr ());
    return _ep;
  }

  //-----------------------------------------------------------------------

  ptr<endpoint_t>
  fsop::unixsock_t::allocate_ep (ptr<labelset_t> ls)
  {
    _p2s = New refcounted<p2s_sockend_t> (_proc->rm (),
					  ls, 
					  _proc->lbund ()->labelset (),
					  _proc->filterset_p (),
					  _arg->c_args.path.cstr ());
    return _p2s;
  }

  //-----------------------------------------------------------------------

  tamed void
  fsop::obj_t::run (evv_t ev)
  {
    tvars {
      ptr<labelset_t> proc_creat_ls;
      ptr<labelset_t> write_ls;
      bool checkit;
      ptr<eval::ctx_t> ctx;
      bool ok (true);
    }

    init_fs_opts ();

    /*
     * If the user specified an EP for the file, and the file is being
     * created, then we'll have to send the FS two different labels;
     * the first is for what endpoint to put when deciding to allow
     * write to the file -- that's in arg->proc as normal.  The second
     * is the labelset used when writing to the parent dir, which is the
     * proc's main labelset at current.  That's in proc_creat_ls.  
     * In the case of not creating, or no special EP specified, then
     * no worries, use arg->proc as usual.
     */
    if (_arg->ep && do_creat ()) {
      proc_creat_ls = _proc->labelset ();
    }

    /*
     * If creating a file, put the endpoint's labelset on the file.
     * If writing, get the appropriate capabilities.
     */
    write_ls = _proc->write_labelset_ep (_arg, &checkit);

    /*
     * Allocate a different EP based on what operating we're performing.
     * Populate the EP appropriately
     */
    _ep = allocate_ep (write_ls);

    if (checkit) {
      ctx = eval::ctx_t::alloc ();
      twait { _ep->check_ep_valid_self (false, mkevent (ok), ctx); }
    }

    if (!ok) {
      assert (ctx);
      ctx->to_xdr (&_res);
    } else {

      twait { 
	_proc->rm()->fsop (fs_opcode (), _proc->cwd (), _arg, write_ls,
			   _fs_opts, &_res, mkevent (), _proc->filterset_p (), 
			   &_path, &_unjailed, proc_creat_ls); 
      }

      twait { process_result (mkevent ()); }

    }
    ev->trigger ();
  }
  
  //-----------------------------------------------------------------------
  
  tamed void
  fsop::obj_t::go (evv_t ev)
  {
    twait { run (mkevent ()); }
    reply ();
  }

  //-----------------------------------------------------------------------

  tamed void
  fsop::obj_t::process_result (evv_t ev)
  {
    tvars {
      bool ok (true);
      bool uniq, hold;
    }

    if (_res.status == FLUME_FDPASS_OK) {
      _fd = _res.fdpass_ok->fd;
      FLUMEDBG4(FS, CHATTER,
		"RM got %s(%s) opened here as fd %d\n", 
		opname(), _arg->c_args.path.cstr(), _fd);

      //
      // 'unique' endpoint; only one needed per process
      // 'hold' endpoint until proc exits
      //
      // If the endpoint check failed, there was an interesting race
      // condition, in which the endpoint used to be OK but now isn't.
      //
      if (keep_endpoint ()) {
	uniq = !is_socket ();
	hold = true;
	twait { 
	  _proc->lbund ()->check_and_insert (_ep, uniq, hold, mkevent (ok)); 
	}
      }
      if (!ok) {
	_res.set_status (FLUME_ERACE);
      }
    }
    
    if (ok) {
      success_result ();
    }
    ev->trigger ();
  }
  
  //-----------------------------------------------------------------------
  
  void
  fsop::obj_t::reply ()
  {
    
    if (_sendfd >= 0) {
      FLUMEDBG4(FD_PASSING, CHATTER, "Sending fd=%d back to client\n", _fd);
      make_sync (_sendfd);
      _x->sendfd (_sendfd);
    }
    
    FLUMEDBG4(FS, CHATTER, "replying to %s (%s) with res.status %d\n", 
	      opname (), _arg->c_args.path.cstr(), _res.status);
    _sbp->replyref (_res);
  }

  //-----------------------------------------------------------------------

  void
  fsop::open_t::success_result () 
  {
    if (_res.status == FLUME_FDPASS_OK) {
      _res.set_status (FLUME_PATH_OK);
      *_res.path = _unjailed;
      _sendfd = _fd;
    }
  }

  //-----------------------------------------------------------------------

  void
  fsop::unixsock_t::success_result ()
  {
    if (_res.status == FLUME_FDPASS_OK) {
      int fds[2];
      int rc = my_socketpair (fds);
      if (rc < 0) {
	close (_fd);
	_res.set_status (FLUME_ERR);
      } else {
	
	// Debug
	FLUMEDBG4(SOCKETS, CHATTER, "handle_unixsocket: Got back fd=%d", _fd);
	
	_res.set_status (FLUME_FDPASS_OK_OPAQUE);
      
	*_res.opaque_h = _p2s->global_id ();
	_proc->fds ()->newsock (_p2s);
	_p2s->set_internal_sock_fd (_fd);
	_p2s->set_my_fd (fds[0]);
	_sendfd = fds[1];
      }
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::handle_unixsocket (svccb *sbp, ptr<axprt_unix> x)
  {
    tvars {
      fsop::unixsock_t op (_self, sbp, x);
    }
    twait { op.go (mkevent ()); }
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_open (svccb *sbp, ptr<axprt_unix> x)
  {
    tvars {
      fsop::open_t op (_self, sbp, x);
    }
    twait { op.go (mkevent ()); }
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::inc_open_count ()
  {
    assert (_opens_in_progress >= 0);
    _opens_in_progress ++;
  }

  //-----------------------------------------------------------------------   

  void
  proc_t::dec_open_count ()
  {
    assert (_opens_in_progress > 0);
    _opens_in_progress --;
  }

  //-----------------------------------------------------------------------   

  tamed void
  proc_t::handle_chdir (svccb *sbp)
  {
    tvars {
      fsop::chdir_t op (_self, sbp);
    }
    twait { op.go (mkevent ()); }
  }

  //-----------------------------------------------------------------------   

  void
  fsop::chdir_t::success_result ()
  {
    if (_res.status == FLUME_OK) {
      _proc->set_cwd (_path);
    }
  }

  //-----------------------------------------------------------------------   
  

};
