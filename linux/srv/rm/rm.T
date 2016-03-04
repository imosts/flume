// -*-c++-*-

#include "async.h"
#include "arpc.h"
#include "flume_prot.h"
#include "rm.h"
#include "systrace_policy.h"
#include <sys/syscall.h>
#include "unixutil.h"
#include "parseopt.h"
#include "flume_ev_debug.h"

namespace rm { 

  //-----------------------------------------------------------------------

  ptr<proc_t>
  rm_t::new_proc (proc_t *parent, int *fdp)
  {
    ptr<proc_t> ret = New refcounted<proc_t> (this, parent);
    if (!ret->new_ctl (fdp)) {
      warn ("Failed to make new proc..\n");
      ret = NULL;
    }
    return ret;
  }

  //-----------------------------------------------------------------------

  void
  rm_t::socket_accept_client ()
  {
    sockaddr_un sun;
    bzero (&sun, sizeof (sun));
    socklen_t sunlen = sizeof (sun);
    int fd = accept (_srvfd, reinterpret_cast<sockaddr *> (&sun), &sunlen);
    if (fd >= 0) {
      ptr<proc_t> proc = New refcounted<proc_t> (this);
      vNew ctl_t (fd, proc);

      proc->set_confined (false);

      // This process was created ad-hoc, and not via the spawn
      // mechanism; therefore, we set this process as not being confied,
      // and it gets hit with ep_bottom.
      FLUMEDBG3(PROCESS, CHATTER, 
	       "[anon process] not confined (gets EP bottom)");
    }
  }

  //-----------------------------------------------------------------------

  bool
  is_ok_res (const file_res_t &res)
  {
    switch (res.status) {
    case FLUME_OK: return true;
    case FLUME_FDPASS_OK: return true;
    case FLUME_LABEL_OK: return true;
    case FLUME_STAT_OK: return true;
    case FLUME_PATH_OK: return true;
    default: return false;
    }
  }

  //-----------------------------------------------------------------------

  void
  rm_t::post_to_socket_claim (ptr<p2p_sockend_t> p, int i)
  {
    handle_t h = p->global_id ();
    assert (i == 0 || i == 1);
    assert (!_socket_claim[i][h]);
    _socket_claim[i].insert (h, p);
  }

  //-----------------------------------------------------------------------

  ptr<p2p_sockend_t>
  rm_t::claim_socket (handle_t h, int i)
  {
    assert (i == 0 || i == 1);
    ptr<p2p_sockend_t> r;
    _socket_claim[i].remove (h, &r);
    return r;
  }

  //-----------------------------------------------------------------------

  proc_t *
  rm_t::get_proc_by_pid (pid_t p)
  {
    return (is_flmpid32 (p) ? _procs_by_flmpid32[p] : _procs_by_pid[p]);
  }

  //-----------------------------------------------------------------------

}
