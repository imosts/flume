
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
#include <sys/syscall.h>

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
#include "flume_internal.h"

#define FLUME_DEBUG_RMCONNECT \
   (FLUME_DEBUG_CONNECT | FLUME_DEBUG_LINKER | FLUME_DEBUG_INTERCEPT )

#ifdef IN_RTLD
int _flume_socket = -1;
int _flume_attempted_connect;
#else
/* #include <pthread.h> */
#ifdef SHARED /* in libc (shared) */
extern int _flume_socket;
extern int _flume_attempted_connect;
#else /* in libc (static) */
static int _flume_socket = -1;
static int _flume_attempted_connect;
#endif
#endif

char *
my_strcpy (char *out, const char *in)
{
  char *dp;
  for ( dp = out; *in ; in++, dp++ ) { *dp = *in; }
  return dp;
}

int
unixsocket_connect_c (const char *path)
{
  struct sockaddr_un sun;
  int fd;

  FLUME_DEBUG (FLUME_DEBUG_CONNECT, stderr, 
	      "unixsocket_connect (%s)\n", path);

  if (strlen (path) >= sizeof (sun.sun_path)) {
#ifdef ENAMETOOLONG
    flume_set_errno ( ENAMETOOLONG);
#else /* !ENAMETOOLONG */
    flume_set_errno (E2BIG);
#endif /* !ENAMETOOLONG */
    return -1;
  }

  memset (&sun, 0, sizeof (sun));
  sun.sun_family = AF_UNIX;
  my_strcpy (sun.sun_path, path);

  fd = real_socket (AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0)
    return -1;
  if (real_connect (fd, (struct sockaddr *) &sun, sizeof (sun)) < 0) {
    close (fd);
    return -1;
  }

  FLUME_DEBUG2 (FLUME_DEBUG_CONNECT,
	      "unixsocket() => " FLUME_PRId "\n", 
	       FLUME_PRId_ARG(fd));

  return fd;
}

/*
 * Check if the environment variables give us a ctl sock FD.
 * Returns: -1 on Error, 0 on No attempt and 1 on success
 */
static int
ctlsock_from_env ()
{
  int fd;

  fd = my_env2num (FLUME_SFD_EV);
  if (fd == FLUME_NO_ENV_ERROR)
    return 0;

  if (fd == FLUME_ATOI_ERROR) {
    FLUME_WARN_PRINTF ("'%s' should be an int\n", FLUME_SFD_EV);
    return -1;
  }

  _flume_socket = fd;

  FLUME_DEBUG2 (FLUME_DEBUG_RMCONNECT,
	       "Attempt to grab RM socket FD from environment: " 
	       FLUME_PRId "\n",
	       FLUME_PRId_ARG(_flume_socket));

  /* verify that the socket works */
  if (rpc_call (FLUME_NULL, NULL, NULL, "libc connect") < 0) {

    /*
     * Always warn if we got a bad FD
     */
    FLUME_WARN_PRINTF( "Given FD to RM (" FLUME_PRId 
		      ") failed to be a good one\n",
		      FLUME_PRId_ARG(_flume_socket));

    _flume_socket = -1;
    return -1;
  }
  return 1;
}

/*
 * Try to connect to the RM socket file, and init the ring level
 * Returns -1 on Failure and 1 on success
 */
static int
ctlsock_connect ()
{
  char *envp;
  int fd;

  if (!(envp = getenv (FLUME_SCK_EV))) {
    return -1;
  }

  // use the default if we got a defined but empty environment variable
  if (!*envp) {
    envp = FLUME_DEFAULT_SOCKET;
  }

  FLUME_DEBUG (FLUME_DEBUG_RMCONNECT, stderr,
	      "Attempting connect to RM on socket: %s\n", envp);

  fd = unixsocket_connect_c (envp);
  if (fd < 0) {
    FLUME_WARN_PRINTF ("cannot connect to socket: %s\n", envp);
  }

  _flume_socket = fd;

  if (rpc_call (FLUME_NULL, NULL, NULL, "libc connect") < 0) {
    FLUME_WARN_PRINTF ("failed to ping RM\n");
    _flume_socket = -1;
  }

  return (_flume_socket >= 0 ? 1 : -1);
}

/*
 * Perhaps we called clone_ctl_sock and we want to use the new instead
 * of the old.
 */
void
flume_setctlsock (int i)
{
  _flume_socket = i;
}


/*
 * If we already know what the ctlsock is or we already connected and
 * failed, return the FD.  Otherwise, try to create a new ctlsock FD and
 * return its value.
 */
int
flume_myctlsock ()
{

#ifndef IN_RTLD
  /*
  FLUME_WARN_PRINTF("my sock: 0x%lx\n", (unsigned long int)pthread_self ());
  */
#endif
  if (_flume_attempted_connect) 
    return _flume_socket;

  _flume_attempted_connect = 1;
  assert (_flume_socket < 0);

  if (ctlsock_from_env () <= 0)
    ctlsock_connect ();

  FLUME_DEBUG2 (FLUME_DEBUG_RMCONNECT,
	       "Program running with Flume socket = " FLUME_PRId "\n", 
	       FLUME_PRId_ARG (_flume_socket));
  
  return _flume_socket;
}
