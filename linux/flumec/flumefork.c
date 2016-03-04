
#include "flume_features.h"

#include <stdlib.h>
#include <limits.h>
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/time.h>
#include "flume_prot.h"
#include <errno.h>
#include <assert.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <unistd.h>

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_clnt.h"
#include "flume_internal.h"

static int real_close (int fd)
{
#ifndef IN_RTLD 
  return syscall (SYS_close, fd);
#else /* !IN_RTLD */
  return -1;
#endif /* IN_RTLD */
}




pid_t
flume_fork (int nfds, const int close_fds[], int confined)
{
  pid_t pid;

  int tmp_pipe[2];
  int hack_pipe[2];
  int rc;
  int child_ctl_fd;
  int i;
  int parent_ctl = flume_myctlsock ();

  if (parent_ctl < 0) {
    FLUME_SET_ERRNO (FLUME_EMANAGEMENT);
    return -1;
  }

  rc = pipe (tmp_pipe);
  if (rc < 0)
    return rc;

  // A hack to make sure child_ctl_fd doesn't conflict with fd 0,1,2
  rc = pipe (hack_pipe);
  if (rc < 0)
    return rc;

  child_ctl_fd = flume_dup_ctl_sock ();

  real_close (hack_pipe[0]);
  real_close (hack_pipe[1]);

  pid = fork ();

  if (pid > 0) {
    real_close (child_ctl_fd);
    real_close (tmp_pipe[0]);
    rc = write (tmp_pipe[1], (void *)&pid, sizeof (pid));
    if (rc < 0) {
      fprintf (stderr, "fork: write on temporary pipe (fds %d, %d) failed rc %d errno %d!\n", 
               tmp_pipe[0], tmp_pipe[1], rc, errno);
    }
    real_close (tmp_pipe[1]);

  } else if (pid == 0) {

    /*
     * Flume's libc caches our pid (since it sometimes involves a call to
     * the RM).  At this point, we need to clear that cache for obvious
     * reasons.
     */
    flume_clear_pid ();

    /*
     * close all pids we were supposed to close
     */
    for (i = 0; i < nfds; i ++) {
      real_close (close_fds[i]);
    }
    real_close (parent_ctl);
    real_close (tmp_pipe[1]);
    flume_setctlsock (child_ctl_fd);

    /*
     * The primary purpose of this read is to ensure that the parent
     * has closed his end of our control socket. If he does not,
     * then checks in confine_me will fail.  Confine_me is called
     * from inside of finish_fork.
     *
     * The second purpose is to get our pid, which we could have done a
     * different way, but we're reading data anyways....
     */
    rc = read (tmp_pipe[0], (void *)&pid, sizeof (pid));
    if (rc != sizeof (pid)) {
      fprintf (stderr,  "fork: short read from parent: %d\n", rc);
      rc = -1;
    } else {
      real_close (tmp_pipe[0]);

      /*
       * Will do 3 important things:
       *   1.  Will make a flume proc_t structure for this proces.
       *   2.  Will confine this process.
       *   3.  Will set the unix pid on the flume side.
       * 
       * Note, internally, flume must check if this process is confineable.
       * That is, it must check that the CTL sock is legit, that there
       * are no other files open, and that this proc has no
       * writable mmap'ed regions.
       *
       */
      rc = flume_finish_fork (child_ctl_fd, pid, confined);
    }

  } else {
    fprintf (stderr, "fork: fork failed!\n");
    rc = pid;
  }

  return rc;
}
