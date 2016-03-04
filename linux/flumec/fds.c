
#include "flume_features.h"

#include <stdlib.h>
#include <limits.h>
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/time.h>
#include <errno.h>
#include <assert.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <netinet/tcp.h>
#include <unistd.h>

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"


#define MAX_FDS 1024
static fd_typ_t fds_status[MAX_FDS];

static int fd_status_init;

void
fds_init ()
{
  if (!fd_status_init) {
    memset (fds_status, 0, sizeof (fds_status));
    fds_status[0] = fds_status[1] = fds_status[2] = FD_SOCKET;
    fd_status_init = 1;
  }
}

// returns 1 if a call should be made to the RM, and 0 otherwise.
int
is_open_flume_socket (int fd)
{
  int ret = 0;
  fds_init ();
  if (fd >= 0 && fd < MAX_FDS) {
    if (fds_status[fd] == FD_SOCKET) {
      ret = 1;
    }
  }
  return ret;
}

void
set_fd_status (int fd, fd_typ_t st)
{
  fds_init ();
  if (fd >= 0 && fd < MAX_FDS) {
    fds_status[fd] = st;
  }
}
