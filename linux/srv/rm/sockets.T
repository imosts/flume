
// -*-c++-*-
#include "rm.h"
#include <sys/types.h>
#include <sys/socket.h>
#include "tame_io.h"
#include "asyncutil.h"

namespace rm {

  //-----------------------------------------------------------------------

  handle_t 
  generic_sockend_t::newh ()
  {
    return global_handlemgr->hfact ()->newh (HANDLE_OPT_IDENTIFIER);
  }

  //-----------------------------------------------------------------------

  p2s_sockend_t::p2s_sockend_t (rm_t *rm, 
				ptr<labelset_t> ls,
				ptr<const labelset_t> pls,
				ptr<const filterset_t> pfs,
				const str &nm)
    : generic_sockend_t (rm, ls, pls, pfs, nm),
      _internal_sock_fd (-1), 
      _listening (false) {}

  //-----------------------------------------------------------------------

  p2p_sockend_t::p2p_sockend_t (rm_t *rm, int fd)
    : generic_sockend_t (rm, fd),
      _duplex (DUPLEX_FULL),
      _wset (false), 
      _rset (false),
      _send_to_proc (-1),
      _in_proxy_loop (false),
      _is_ready (true)
  {}

  //-----------------------------------------------------------------------

  generic_sockend_t::generic_sockend_t (rm_t *rm, int m)
    : endpoint_t (EP_RW),
      _rm (rm), 
      _my_fd (m), 
      _destroyed (New refcounted<bool> (false)),
      _global_id (newh ())
  {}

  //-----------------------------------------------------------------------

  // A constructor for unix sockets, which are half files, and
  // half sockets.
  generic_sockend_t::generic_sockend_t (rm_t *rm,
					ptr<labelset_t> ls,
					ptr<const labelset_t> pls,
					ptr<const filterset_t> pfs,
					const str &nm)
    : endpoint_t (ls, EP_RW, pls, pfs, nm),
      _rm (rm),
      _my_fd (-1),
      _destroyed (New refcounted<bool> (false)),
      _global_id (newh ())
  {}

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::now_i_am_ready ()
  {
    _is_ready = true;
    if (_ready_ev) {
      evv_t::ptr e = _ready_ev;
      _ready_ev = NULL;
      e->trigger ();
    }

  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::wait_until_ready (evv_t ev)
  {
    if (_is_ready) {
      ev->trigger ();
    } else {
      _ready_ev = ev;
    }
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::i_am_not_yet_ready ()
  {
    _is_ready = false;
  }

  //-----------------------------------------------------------------------

  p2p_sockend_t::~p2p_sockend_t ()
  {
    int fd;
    do_disconnect ();
    if (_send_to_proc.has (&fd) && fd >= 0) {
      close (fd);
    }
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::do_disconnect ()
  {
    if (_other_end) {
      _other_end->disconnect ();
      _other_end = NULL;
    }
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::disconnect ()
  {
    clear_write ();
    _other_end = NULL;
  }

  //-----------------------------------------------------------------------

  p2s_sockend_t::~p2s_sockend_t ()
  {
    if (_internal_sock_fd >= 0) {
      close (_internal_sock_fd);
    }
  }

  //-----------------------------------------------------------------------

  void
  generic_sockend_t::close_my_fd ()
  {
    if (_my_fd >= 0) {
      tame::clearread (_my_fd);
      FLUMEDBG4(SOCKETS, CHATTER, "Close FD=%d\n", _my_fd);
      close (_my_fd);
      _my_fd = -1;
    }
  }

  //-----------------------------------------------------------------------

  generic_sockend_t::~generic_sockend_t ()
  {
    FLUMEDBG4(SOCKETS, CHATTER, "Destroy socket: %p\n", this);
    *_destroyed = true;
    close_my_fd ();
  }

  //-----------------------------------------------------------------------

  void
  generic_sockend_t::orphaned ()
  {
    safevtrig (&_call_on_orphanage);
  }

  //-----------------------------------------------------------------------

  tamed flume_status_t
  p2s_sockend_t::listen_loop (int q)
  {
    tvars {
      flume_status_t ret (FLUME_OK);
      rendezvous_t<generic_sockend_t::event_t> G (__FILE__, __LINE__);
      bool go;
      int nfd;
      struct sockaddr_in sin;
      socklen_t sinlen;
      u_int64_t i;
      ptr<p2p_sockend_t> ns;
      int rc;
      ssize_t hsz (sizeof (u_int64_t));
      generic_sockend_t::event_t status;
      str tmp;
      int lfd;
      ptr<p2s_sockend_t> hold;
    }
    DEFAULT_RETURN { return ret; }

    // Listen can be called only once on this thing.
    if (_listening) {
      ret = FLUME_EEXIST;
      return ret;
    } else {
      _listening = true;
    }

    // We want to keep one reference of this socket so that we're
    // always in scope.
    hold = mkref (this);

    lfd = _internal_sock_fd;

    if ( listen (lfd, q) < 0) {
      warn ("Listen failed on fd=%d: %m\n", lfd);
      ret = FLUME_ERR;
      return ret;
    }

    _call_on_orphanage = mkevent (G,SOCKET_DELETE);

    make_async (lfd);
    tame::waitread (lfd, mkevent (G,SOCKET_SELREAD));
    make_async (_my_fd);
    tame::waitread (_my_fd, mkevent (G,SOCKET_EOF));

    go = true;
    while (go) {
      twait (G, status);
      go = false;
      
      switch (status) {
      case SOCKET_SELREAD: 
	tame::waitread (lfd, mkevent (G,SOCKET_SELREAD));

	nfd = accept (lfd, reinterpret_cast<sockaddr *> (&sin), &sinlen);
	if (nfd < 0) {
	  warn ("Accept on fd=%d returned error: %m\n", lfd);
	} else {

	  ns = New refcounted<p2p_sockend_t> (rm (), nfd);
	  tmp = ns->to_str ();

	  ns->i_am_not_yet_ready ();
	  
	  FLUMEDBG4(SOCKETS, CHATTER, "New p2p sockend in listen loop: %s",
		   tmp.cstr ());
	  
	  i = ns->global_id ().value ();
	  rc = write (nfd, static_cast<const void *> (&i), hsz);
	  if (rc != hsz) {
	    warn ("Short write in socket end in listen loop: %d\n", rc);
	  } else {

	    // Note 2 people need to claim this socket, in one way or
	    // another; first, someone who called 'accept', and second
	    // the other end of it.
	    for (i = 0; i < 2; i++) {
	      rm ()->post_to_socket_claim (ns, i);
	    }
	    
	    // tell the server(s) that a new connection is ready,
	    // and that they should come and claim it.
	    notify_listeners (ns);

	    ns = NULL;
	    go = true; 
	  }
	}
	break;

      case SOCKET_EOF:
	{
#define BUFSZ 128
	  char buf[BUFSZ];
	  int rc = read (_my_fd, buf, BUFSZ);
	  if (rc > 0) {
	    warn ("Got data on fd=%d but didn't expect any!\n", _my_fd);
	  } else if (rc < 0) {
	    warn ("Error on fd=%d: %m\n", _my_fd);
	  } else {
	    FLUMEDBG4(SOCKETS, CHATTER, 
		     "Server listen loop: EOF on fd=%d", _my_fd);
	  }
#undef BUFSZ
	}
	break;

      case SOCKET_DELETE:
	tmp = to_str ();
	FLUMEDBG4(SOCKETS, CHATTER, "Issued delete on socket: %s", tmp.cstr ());
	break;
	
      default:
	panic ("Unexpected enum case: %d\n", int (status));
	break;
      }
	
    }

    // clean up 
    tame::clearread (lfd);
    tame::clearread (_my_fd);
    _call_on_orphanage = NULL;

    G.cancel ();

    if (FLUMEDBG2(SOCKETS)) {
      str tmp = to_str ();
      flumedbg_warn (CHATTER, "Exit from server listen loop: %s", tmp.cstr ());
    }
  }

  //-----------------------------------------------------------------------

  //Called on behalf of the client, when the client is creating a
  //socket on which it will eventually call "connect()" to connect to
  //a named unix socket.
  tamed void
  proc_t::create_dangling_socket (handle_t *hp, open_cb_t cb)
  {
    tvars {
      int fds[2];
      str tmp;
      ptr<p2p_sockend_t> nse;
      flume_status_t stat;
    }
    
    if (my_socketpair (fds) < 0) {
      warn ("Socketpair returned an error: %m\n");
      stat = FLUME_EINVAL;
    } else {
      // Send the handles back to the client.  Recall, however, that
      // whenever we send a FD to a client (or server) we need to keep
      // track of the RM's FD and also the processes FD.  Hence, we
      // need yet another identifier to make this exchange happen.
      
      // We have fds[0] and fds[1]. Keep fds[0] for ourself and send
      // fds[1] back to the client.
      nse = New refcounted<p2p_sockend_t> (rm (), fds[0]);
      nse->set_proc (_lbund);
      
      *hp = nse->global_id ();
      
      // Register the socket end as a new socket, that way the client
      // can register back, etc.
      _fds.newsock (nse);
      
      // The socket is not connected to anything yet.  We will connect it
      // when the client calls "connect()".
      
      if (FLUMEDBG2(SOCKETS)) {
        flumedbg_warn (CHATTER, "create_dangling_socket");
        tmp = nse->to_str ();
        flumedbg_warn (CHATTER, "\tNew: %s", tmp.cstr ());
      }
      stat = FLUME_OK;
    }
    cb->trigger (stat, fds[1]);
  }

  //-----------------------------------------------------------------------

  // Called on behalf of the client, when the client is connecting a
  // previously created, dangling socket to a named Unix socket.
  // <client_fd> is the fd of the client's socket in the client's
  // address space.  <rm_fd> is the fd that the RM got from calling
  // unixconnect on the named socket.
  tamed void
  proc_t::connect_socket (int client_fd, int rm_fd, cbb cb)
  {
    tvars {
      int rc;
      u_int64_t i;
      handle_t h;
      ssize_t hsz (sizeof (u_int64_t));
      ptr<p2p_sockend_t> clnt_end, srv_end;
      flume_status_t stat;
      str tmp;
      bool ok;
    }

    make_async (rm_fd);
    twait { tame::waitread (rm_fd, mkevent ()); }
    
    rc = read (rm_fd, static_cast<void *> (&i), hsz);
    if (rc != hsz) {
      warn ("Short read on socket end in listen loop: %d\n", rc);
      stat = FLUME_EIO;
    } else {
      h = i;

      if (!(clnt_end = _fds[client_fd]->to_p2p ())) {
        warn ("Could not find the sockend referenced by the client\n");
        stat = FLUME_EINVAL;

      // Make sure that we can lookup the opaque socket identifier in the
      // table of currently active identifiers. The "1" as the second
      // argument means that we're fetching from the internal
      // switchboard socket claim, used only for this purpose.
      } else if ((srv_end = rm ()->claim_socket (h, 1))) {

	twait { srv_end->wait_until_ready (mkevent ()); }

	twait { 
	  // make sure that the server process can have a per-FD
	  // label set to the client's....
	  srv_end->relabel_server_fd (labelset ()->deep_clone (), 
                                      mkevent (ok)); 
	}
	if (!ok) {
	  FLUMEDBG3(SOCKETS, ERROR, "Relabel operation failed");
	  stat = FLUME_EPERM;
        } else if (srv_end->is_connected ()) {
	  FLUMEDBG3(SOCKETS, ERROR, "Server end already connected!");
	  stat = FLUME_EPERM;
        } else if (clnt_end->is_connected ()) {
	  FLUMEDBG3(SOCKETS, ERROR, "Client end already connected!");
	  stat = FLUME_EPERM;
	} else {
	  // Once all the checks have succeeded, we're ready to
	  // connect the client sockend with the server sockend.
          srv_end->connect (clnt_end);
          clnt_end->connect (srv_end);
          
	  //
	  // Send the original socketpair we got from calling 
	  // unix_socketconnect and listen back to the server.  This is
	  // somewhat of a hack to avoid having to make a new socketpair.
	  //
	  // When that server claims the FD, we'll start the proxy
	  // loop (see claim() below)...
	  //
          srv_end->set_send_to_proc (rm_fd);

	  if (FLUMEDBG2(SOCKETS)) {
	    flumedbg_warn (CHATTER, "Client connected to unix socket");
	    tmp = srv_end->to_str ();
	    flumedbg_warn (CHATTER, "\nunix socket: %s", tmp.cstr ());
          }
          stat = FLUME_OK;
        } 
      } else {
	tmp = h.to_str ();
	warn ("Socket not found: h=%s\n", tmp.cstr ());
	stat = FLUME_ENOENT;
      }
    }
    cb->trigger (stat ? 0 : 1);
  }
  
  //-----------------------------------------------------------------------

  tamed void
  p2s_sockend_t::notify_listeners (ptr<p2p_sockend_t> p)
  {
    tvars {
      int rc;
      u_int64_t v;
      str tmp;
      ptr<bool> df;
      int fd;
      handle_t h (p->global_id ());
    }

    df = _destroyed;
    fd = _my_fd;

    twait { tame::waitwrite (fd, mkevent ()); }
    if (!*df) {
      
      tmp = h.to_str ();
      FLUMEDBG4(SOCKETS,CHATTER, 
	       "On fd=%d, notifying listeners of new sockend ID=%s", 
	       fd, tmp.cstr ());
      
      v = h.value ();
      rc = write (fd, static_cast<const void *> (&v), sizeof (v));
      if (rc != sizeof (v)) {
	warn ("Short write in notify_listeners\n");
	if (rc < 0) {
	  warn ("Error given was: %m\n");
	}
      }
    }
  }

  //-----------------------------------------------------------------------

  bool
  p2p_sockend_t::can_send_across ()
  {
    bool res, dummy;
    comm_allowed (&res, &dummy);
    return res;
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::comm_allowed (bool *me_to_them, bool *them_to_me)
  {
    ptr<const labelset_t> me, them;
    ptr<const labelset_t> tmp;
 
    
    effective_labelset (&tmp);
    me = tmp;

    if (_label_on_close) {
      them = _label_on_close;
    } else if (_other_end) {
      _other_end->effective_labelset (&tmp);
      them = tmp;
    } else {
      them = labelset_t::null ();
    }
    
    *me_to_them = (*me <= *them);
    *them_to_me = (*them <= *me);
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::signal_eof ()
  {
    if (!_in_proxy_loop) {
      FLUMEDBG4(SOCKETS, CHATTER, "EOF came before in proxy loop: %p", this);
    } else {
      safevtrig (&_call_on_eof);
    }
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::clear_read () 
  {
    if (_rset) { 
      FLUMEDBG4(SOCKETS, CHATTER, "Disabling selread on FD=%d\n", _my_fd);
      tame::clearread (_my_fd);
      fdcb (_my_fd, selread, NULL);
      _rset = false;
    }
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::fdcb_read (cbv cb)
  {
    if (_my_fd >= 0) {
      FLUMEDBG4(SOCKETS, CHATTER, "Enabled selread on FD=%d\n", _my_fd);
      fdcb (_my_fd, selread, cb);
      _rset = true;
    }
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::clear_write ()
  {
    int i = other_side_fd ();
    if (_wset && i >= 0) {
      FLUMEDBG4(SOCKETS, CHATTER, "Disabling selwrite on FD=%d\n", i);
      fdcb (i, selwrite, NULL);
      _wset = false;
    }
  }

  //-----------------------------------------------------------------------

  int
  p2p_sockend_t::other_side_fd () const
  {
    return _other_end ? _other_end->my_fd () : -1;
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::fdcb_write (cbv cb)
  {
    int i = other_side_fd ();
    FLUMEDBG4(SOCKETS, CHATTER, "Enabled selwrite on FD=%d\n", i);
    assert (i >= 0);
    fdcb (i, selwrite, cb);
    _wset = true;
  }

  //-----------------------------------------------------------------------

  typedef enum { PROXY_NONE,
		 PROXY_THEY_CLOSED_LABEL_WAIT,
		 PROXY_THEY_CLOSED,
		 PROXY_I_CLOSED_WRITE_WAIT,
		 PROXY_I_CLOSED,
		 PROXY_BOTH_CLOSED } proxy_state_t;

  //-----------------------------------------------------------------------

  static bool
  keep_looping (proxy_state_t st) 
  {
    return (st != PROXY_THEY_CLOSED &&
	    st != PROXY_I_CLOSED &&
	    st != PROXY_BOTH_CLOSED);
  }

  //-----------------------------------------------------------------------

  static bool
  they_closed (proxy_state_t st)
  {
    return (st == PROXY_THEY_CLOSED || st == PROXY_THEY_CLOSED_LABEL_WAIT);
  }

  //-----------------------------------------------------------------------

  static bool
  i_closed (proxy_state_t st)
  {
    return (st == PROXY_I_CLOSED || st == PROXY_I_CLOSED_WRITE_WAIT);
  }

  //-----------------------------------------------------------------------

  static void
  flushed (proxy_state_t *st, size_t bytes, p2p_sockend_t *oe)
  {
    assert (*st == PROXY_I_CLOSED_WRITE_WAIT);
    if (bytes == 0) {
      *st = PROXY_I_CLOSED;
      if (oe) {
	oe->signal_eof ();
	FLUMEDBG3(SOCKETS, CHATTER, "Sending EOF signal to other end");
      } else {
	FLUMEDBG3(SOCKETS, CHATTER, "No EOF signal due to NULL other end");
      }
    } else {
      FLUMEDBG3(SOCKETS, CHATTER, "No EOF signal due to pending bytes");
    }
  }
 

  //-----------------------------------------------------------------------

  tamed void
  p2p_sockend_t::proxy_loop ()
  {
    tvars {
      rendezvous_t<generic_sockend_t::event_t> G (__FILE__, __LINE__);
      suio buf;
      size_t buflim (0x10000);
      generic_sockend_t::event_t status;
      ptr<bool> df;
      bool m2t, t2m; /* me->them and them->me */
      ssize_t rc;
      proxy_state_t state (PROXY_NONE);
      ptr<p2p_sockend_t> hold;
      ptr<const labelset_t> tmp;
    }

    assert (!_in_proxy_loop);
    _in_proxy_loop = true;

    df = _destroyed;

    // we still hold onto ourselves even if everyone else lets
    // go of us.
    hold = mkref (this);

    assert (!_call_on_orphanage && !_call_on_label_change);

    // Other 'threads of control' will call this callback when our
    // labels have changed.
    _call_on_label_change = mkevent (G,SOCKET_LABELCHANGE);

    // Called by the other end of the socket when their side closed.
    // If a queued EOF, then the other side already sent the signal.
    if (_other_end)
      _call_on_eof = mkevent (G,SOCKET_EOF);

    // Called when this socket end is orphaned; not sure yet what
    // it's going to do.
    _call_on_orphanage = mkevent (G, SOCKET_DELETE);

    // Initialize flags saying in which ways communication is allowed
    // (see below for more extensive comment).
    comm_allowed (&m2t, &t2m);

    if (!_other_end)
      state = t2m ? PROXY_THEY_CLOSED : PROXY_THEY_CLOSED_LABEL_WAIT;
 
    if (FLUMEDBG2(PROXY)) {
      str tmp = to_str ();
      flumedbg_warn (CHATTER, "Run proxy loop: %s\n", tmp.cstr ());
    }

    {
      // Initialized FD's so that they don't block us
      if (_my_fd >= 0)
	make_async (_my_fd);
      
      int fd = other_side_fd ();
      if (fd >= 0) 
	make_async (fd);
    }

    //
    // If ever both sides close (i.e., if second_close is true) then
    // stop immediately.  Otherwise, keep looping on a half-closed connection
    // so long as the other side cannot send messages to us.
    //
    while (keep_looping (state)) {

      //
      // We can only read if our side hasn't closed; we must not
      // be in state PROXY_I_CLOSED_WRITE_WAIT.
      //
      // Once this condition is satisfied, there are 3 possible scenarios
      // in which we should read from the user process writing to our
      // end of the socketpair:
      //
      //   (1) There is room left in our buffer
      //   (2) We cannot write to them and therefore we should stop buffering
      //       and just drop packets.
      //   (3) The other side is dead, and we can't know about it; in
      //       which case, we still need to keep pretending to write from
      //       us to them.
      //
      if (state != PROXY_I_CLOSED_WRITE_WAIT &&
	  (buf.resid () < buflim || !m2t || 
	   state == PROXY_THEY_CLOSED_LABEL_WAIT)) {

	fdcb_read (mkevent (G, SOCKET_SELREAD));
      }

      if (!_other_end) {

	// If the other end is not there, then we should only be
	// looping because our side can't know that they closed.
	assert (state == PROXY_THEY_CLOSED_LABEL_WAIT);
	assert (!t2m);

      } else {
      
	if (_other_end && buf.resid () && m2t && other_side_fd () >= 0) {
	  FLUMEDBG4 (PROXY, CHATTER, "Setting write with %d bytes in buffer\n",
		    int (buf.resid ()));
	  fdcb_write (mkevent (G, SOCKET_SELWRITE));
    
	}

      }
      
      twait (G, status);
      
      if (FLUMEDBG2(PROXY)) {
	str tmp = to_str ();
	flumedbg_warn (CHATTER, "Proxy wakeup (status=%d, state=%d): %s\n",
		      int (status), int (state), tmp.cstr ());
      }
      
      //
      // Deteremines if communication is allowed between us and them;
      // first argument is me->them, second is them->me.
      //
      comm_allowed (&m2t, &t2m);

      FLUMEDBG4(PROXY, CHATTER, "me2them: %d; them2me: %d\n", 
	       m2t ? 1 : 0, t2m ? 1 : 0);

      // always check to see if the other side disconnected...
      if (!_other_end || status == SOCKET_EOF) {
	// A message came from the other end that their end
	// of the socket is closed.
	state = t2m ? PROXY_THEY_CLOSED : PROXY_THEY_CLOSED_LABEL_WAIT;

	// No need to write after an EOF, but we still might need
	// to read for another EOF arrival (from the other end of
	// the socket).
	clear_write ();

      }

      
      switch (status) {
	
      case SOCKET_EOF:
	// the status code is handled above
	FLUMEDBG4(PROXY, CHATTER, "EOF message received: %p\n", this);
	break;
      case SOCKET_DELETE:
	FLUMEDBG4(PROXY, CHATTER, "Socket deleted/orphaned: %p\n", this);
	break;
	
      case SOCKET_SELREAD:
	// Reading data from **the user process.**
	assert (_rset);

	// The buffer is full, but we can't write to them; thus,
	// our buffered data is nuked.
	if (buf.resid () == buflim && !m2t) {
	  buf.clear ();
	}

	// EOF here means that the process writing to us
	// has called close(). We can close up one half of
	// the conection, but it might be a leak to release
	// the EOF to the other side.
	if (buflim > buf.resid () &&  
	    (rc = buf.input (_my_fd, buflim - buf.resid ())) == 0) {

	  FLUMEDBG4(PROXY,CHATTER, "EOF on fd=%d\n", _my_fd);
	  
	  if (_other_end) {
	    state = PROXY_I_CLOSED_WRITE_WAIT;

	    // Tell the other side our label at the time of the close.
	    effective_labelset (&tmp);
	    _other_end->_label_on_close = tmp->deep_clone ();

	    // Potentially transition away from "WRITE_WAIT" state
	    // if we have nothing more in our buffer.
	    // Note: flushed might clear '_other_end'
	    flushed (&state, buf.resid (), _other_end);

	    // The other end needs to clear its write, since we're 
	    // about to zero-out "_my_fd".
	    // If we EOF, we better be certain that the other side
	    // is not trying to write to us; if so, they'll get
	    // EPIPEs. 
	    if (_other_end)
	      _other_end->clear_write ();

	  } else {
	    // otherwise, we were the second to close, and we're done
	    state = PROXY_BOTH_CLOSED;
	  }
	}

	// Recompute whether to select on readability the next time
	// through the loop.
	clear_read ();

	// Only can do this after we cleared read and write callbacks.
	if (i_closed (state)) { 
	  close_my_fd ();
	}

	break;
	
      case SOCKET_SELWRITE:
	// Write data to the other RM object for this socketpair.
	assert (!they_closed (state));
	assert (_wset);

	if (m2t) {
	  // Write data to the other end -- output whatever is in 
	  // the buffer 'buf'.
	  rc = buf.output (other_side_fd ());
	  if (rc < 0 && errno != EAGAIN) {
	    warn ("Error writing to fd %d in proxy loop: %m\n", other_side_fd ());
            buf.clear ();
          }

	  // It might have been the case that this was the last flush
	  // needed before we can tell the other side that we closed
	  // up shop....
	  if (state == PROXY_I_CLOSED_WRITE_WAIT)
	    flushed (&state, buf.resid (), _other_end);
	}

	// Recompute whether to select on writability the next time
	// through the loop.
	clear_write ();

	break;
	
      case SOCKET_LABELCHANGE:

	// Immediately expect another label change
	_call_on_label_change = mkevent (G,status);

	// Recompute whether we should be waiting for a read/write
	// the next time through the loop.
	clear_read ();
	clear_write ();

	break;
	
      default:
	panic ("unexpected case: %d\n", int (status));
	break;
      }
    }
    FLUMEDBG3(PROXY,CHATTER,"Leaving proxy loop\n");
    
    // Cleanup any outstanding callbacks.
    clear_read ();
    clear_write ();

    if (_call_on_label_change)  _call_on_label_change = NULL;
    if (_call_on_eof) _call_on_eof = NULL;
    if (_call_on_orphanage) _call_on_orphanage = NULL;
    
    do_disconnect ();
    close_my_fd ();

    G.cancel ();

    FLUMEDBG3(PROXY,CHATTER, "Finished GC phase\n");
    
    assert (!_wset);
    assert (!_rset);

    FLUMEDBG4(PROXY,CHATTER, "Derefence hold on sockend: %p\n", this);
    hold = NULL;
  }

  //-----------------------------------------------------------------------

  void
  generic_sockend_t::poke_label_change ()
  {
    poke_label_change_do1side ();
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::poke_label_change ()
  {
    poke_label_change_do1side ();
    if (_other_end)
      _other_end->poke_label_change_do1side ();
  }

  //-----------------------------------------------------------------------

  void
  generic_sockend_t::poke_label_change_do1side ()
  {
    _cached_effective_labelset = NULL;
    str tmp = to_str ();
    FLUMEDBG4(SOCKETS, CHATTER, "poke_label_change: %s\n", tmp.cstr ());
    safevtrig (&_call_on_label_change);
  }

  //-----------------------------------------------------------------------

  str
  p2p_sockend_t::to_str () const
  {
    strbuf b;
    str s = global_id ().to_str ();
    b.fmt ("p2p_sockend_t (this=%p): id=%s, _my_fd=%d, _other_end=%p;",
	   this, s.cstr (), _my_fd, static_cast<p2p_sockend_t *> (_other_end));
    str ret = b;
    b.tosuio ()->clear ();
    return ret;
  }

  //-----------------------------------------------------------------------

  str
  p2s_sockend_t::to_str () const
  {
    strbuf b;
    str s = global_id ().to_str ();
    b.fmt ("p2s_sockend_t (this=%p): id=%s, _my_fd=%d, _internal_fd=%d",
	   this, s.cstr (), _my_fd, _internal_sock_fd);
    str ret = b;
    b.tosuio ()->clear ();
    return ret;
  }
    
  //-----------------------------------------------------------------------

  tamed void 
  generic_sockend_t::relabel_server_fd (ptr<labelset_t> ls, cbb cb)
  {
    tvars {
      flume_status_t stat;
      str s;
    }
    if (FLUMEDBG2(SOCKETS)) {
      s = to_str ();
      str l;
      if (ls) {
	l = ls->to_str ();
      } else {
	l = "{}";
      }
      FLUMEDBG4(SOCKETS, CHATTER, "%s: relabel_on_fd(%s)", 
	       s.cstr (), l.cstr ());
    }
	     
    twait { set_labels (ls, mkevent (stat)); }

    if (FLUMEDBG2(SOCKETS)) {
      str r = status2str (stat);
      FLUMEDBG4 (SOCKETS, CHATTER, "%s: relabel => %s", s.cstr (), r.cstr ());
    }

    cb->trigger (stat == FLUME_OK);
  }

  //-----------------------------------------------------------------------

  //
  // Make a unix pipe or socket pair, and stick the results into
  // a struct that we're going to send back over the RPC.  Also return
  // a filedescriptor back to the caller, or -1 in the case of error;
  int
  proc_t::make_uposp (pipe_res_t *pr, duplex_t dup, const socketpair_arg_t *a)
  {
    ptr<p2p_sockend_t> s[2];
    int fds[4];
    rcset_t<int> rcs(2,0);
    int *fp;
    int ret = 0;
    

    // 
    // There are two cases:
    //
    // 1.  We're writing or it's bidirectional (index=1)
    //
    //       Our Proc        rm/us       rm/them       Their Proc
    //        fds[1]   -->   fds[0]   ->  fds[3]  --->  fds[2]
    //
    // 0.  We're reading (index=0)
    //
    //       Our Proc        rm/us       rm/them       Their Proc
    //        fds[0]   <--   fds[1]  <--  fds[2]  <---- fds[3]
    //

    int my_fds[2][2] =    { {1, 2}, {0, 3} };
    int their_fds[2][2] = { {0, 3}, {1, 2} };

    for (int i = 0; i < 4; i++) {
      fds[i] = -1;
    }

    // Index=1 in the case of writers/bi and Index=0 otherwise
    int index = (dup & int (DUPLEX_ME_TO_THEM)) ? 1 : 0;

    for (int i = 0; i < 2 && ret >= 0; i++) {
      fp = fds + i *2;
      if (dup == int (DUPLEX_FULL)) {
	if (socketpair (a, fp) < 0) {
	  warn ("socketpair failed: %m\n");
	  ret = -1;
	}
      } else {
	if (pipe (fp) < 0) {
	  warn ("pipe(2) failed: %m\n");
	  ret = -1;
	}
      }
    }

    if (ret >= 0) {
      for (int i = 0; i < 2; i++) {
	int fd = fds[my_fds[index][i]];
	s[i] = New refcounted<p2p_sockend_t> (rm (), fd);
	s[i]->set_duplex (i == 0 ? dup : invert_duplex (dup));
      }
      s[0]->set_proc (_lbund);
    }

    if (ret >= 0) {
    
      rm ()->post_to_socket_claim (s[1]);
      s[0]->connect (s[1]);
      s[1]->connect (s[0]);
      
      _fds.newsock (s[0]);
      s[1]->set_send_to_proc (fds[their_fds[index][1]]);
      
      pr->set_status (FLUME_OK);
      pr->hpair->my_end = s[0]->global_id ();
      pr->hpair->their_end = s[1]->global_id ();

      // Set the description on this socket, so we can debug it later
      if (a && a->desc && a->desc.len ()) {
	s[0]->set_desc (a->desc);
      }
    
      ret = fds[their_fds[index][0]];

    } else {
      
      pr->set_status (FLUME_EIO);
      for (int i = 0; i < 4; i++) 
	if (fds[i] >= 0) close (fds[i]);

    }
    return ret;
  }

  //-----------------------------------------------------------------------

  tamed void
  proc_t::claim_sockend (claim_res_t *r, claim_arg_t arg, cbi cb)
  {
    tvars {
      ptr<p2p_sockend_t> p;
      int fd (-1);
    }

    if ((p = rm ()->claim_socket (arg.token))) {
      if (arg.desc && arg.desc.len ()) {
	p->set_desc (arg.desc);
      }
      _fds.newsock (p);
      twait { p->claim (r, _lbund, mkevent (fd)); }
    } else {
      r->set_status (FLUME_ENOENT);
    }
    cb->trigger (fd);
  }

  //-----------------------------------------------------------------------

  tamed void
  p2p_sockend_t::claim (claim_res_t *r, ptr<proc_label_bundle_t> b, cbi cb)
  {
    tvars {
      int fd (-1);
      bool ok;
    }

    /*
     * Note the following 3 calls must be in this exact order.
     * First, there's nothing to stop this process from claiming the
     * socket and attaching itself to it, since no other process
     * can now claim it.  Once it's assigned itself, then the client
     * is safe to go ahead and 'relabel_server_fd'.  Once that happens,
     * then the client will give us our fd via '_send_to_proc.get'
     *
     */

    set_proc (b);
    now_i_am_ready ();
    twait { _send_to_proc.get (mkevent (ok, fd)); }

    if (!ok) {
      r->set_status (FLUME_EEXIST);
    } else {

      r->set_status (FLUME_OK);
      r->ok->duplex = duplex ();
      r->ok->opaque_h = global_id ();

      start_proxy_loop ();
      if (other_side ())
	other_side ()->start_proxy_loop ();
    }
    cb->trigger (fd);
  }

  //-----------------------------------------------------------------------

  void
  p2p_sockend_t::start_proxy_loop ()
  {
    // always loop, even if we don't really expect data...
    /* if (duplex () & DUPLEX_ME_TO_THEM) */
    proxy_loop ();
  }

  //-----------------------------------------------------------------------

  flume_status_t 
  proc_t::register_fd (const register_fd_arg_t &arg)
  {
    bool ok = _fds.regsock (arg.rm_side, arg.proc_side);
    return (ok ? FLUME_OK : FLUME_ENOENT);
  }

};
