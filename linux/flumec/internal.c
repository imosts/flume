
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
#include <sys/syscall.h>
#include <sys/stat.h>

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_internal.h"
#include "flume_pid.h"

#include "socketcall.h"

int
rpc_call_fd (int proc, void *in, void *out, const char *cmd, int *outfd)
{
  int rc = -1;
  int ctl_fd;
  enum clnt_stat e;
  
  if ((ctl_fd = flume_myctlsock()) < 0) {
    FLUME_DEBUG (FLUME_DEBUG_CONNECT, stderr, 
		"Cannot connect to the RM's socket.\n");
    FLUME_SET_ERRNO (FLUME_ENOTCONN);
  } else if ((e = srpc_call_fd (&flume_prog_1, ctl_fd, proc, in, out, 
				outfd)) != RPC_SUCCESS) {
    FLUME_DEBUG2 (FLUME_DEBUG_CONNECT, 
		 "In %s (proc=" FLUME_PRId "): RPC Error: " FLUME_PRId "\n", 
		 cmd, 
		 FLUME_PRId_ARG (proc),
		 FLUME_PRId_ARG((int )e));
    FLUME_SET_ERRNO (FLUME_ERPC);
  } else {
    rc = 0;
  }
  return rc;
}

int
rpc_call (int proc, void *in, void *out, const char *cmd)
{
  return rpc_call_fd (proc, in, out, cmd, NULL);
}

int 
my_str2num (const char *in)
{
  long slval;
  unsigned long lval;
  int ok;

  lval = flume_strtoul (in, &ok);

  if (!ok) {
    slval = FLUME_ATOI_ERROR;
  } else {
    slval = lval;
  }

  return slval;
}

/* 
 * -2 = not set
 * -1 = ATOI error
 * >= 0  => success
 */
int 
my_env2num (const char *k)
{
  int rc;
  char *envp = getenv (k);
  if (envp) {
    rc = my_str2num (envp);
  } else {
    rc = FLUME_NO_ENV_ERROR;
  }
  return rc;
}

int
register_fd (int fd, const x_handle_t h)
{
  /* returns 1 on success, 0 on failure */

  register_fd_arg_t arg;
  flume_status_t res;
  int rc = -1;

  arg.proc_side = fd;
  arg.rm_side = h;

  if (rpc_call (FLUME_REGISTER_FD, &arg, &res, "register_fd") < 0) {
    /* noop */
  } else if (res != FLUME_OK) {
    FLUME_SET_ERRNO (res);
  } else {
    rc = 0;
  }

  return rc;
}

#if defined(SYS_socketcall) && (SYS_socketcall > 0)
# define FLUME_socket_syscallno SYS_socketcall
#else
# define FLUME_socket_syscallno SYS_socket
#endif 

/* Real syscalls, compiled once for linker and twice for libc. */
int 
real_socket (int domain, int type, int protocol)
{
#if IN_RTLD
  return socket (AF_UNIX, SOCK_STREAM, 0);
#else
  struct {
    int domain;
    int type;
    int protocol;
  } args;
  args.domain = domain;
  args.type = type;
  args.protocol = protocol;

  int rc = syscall (FLUME_socket_syscallno, SOCKOP_socket, &args);
  FLUME_DEBUG2 (FLUME_DEBUG_LIBC, "flumelibc: real socket, returning %d, errno %d\n", rc, errno);
  return rc;
#endif
}

int
real_connect (int sockfd, const struct sockaddr *serv_addr, 
              socklen_t attrlen)
{
#if IN_RTLD
  return connect (sockfd, serv_addr, attrlen);
#else
  struct {
    int sockfd;
    const struct sockaddr *serv_addr;
    socklen_t attrlen;
  } args;
  args.sockfd = sockfd;
  args.serv_addr = serv_addr;
  args.attrlen = attrlen;

  int rc = syscall (FLUME_socket_syscallno, SOCKOP_connect, &args);
  if (flume_do_debug (FLUME_DEBUG_LIBC)) {
    FLUME_WARN_PRINTF ("flumelibc: real connect, returning %d errno %d\n", 
		       rc, errno);
    switch (serv_addr->sa_family) {
    case AF_UNIX:
      FLUME_WARN_PRINTF ("flumelibc:   path %s\n", 
			 ((struct sockaddr_un *)serv_addr)->sun_path);
      break;
    case AF_INET:
      FLUME_WARN_PRINTF ("flumelibc:   addr %x %d\n", 
                         ntohl(((struct sockaddr_in *)serv_addr)->sin_addr.s_addr),
                         ntohs(((struct sockaddr_in *)serv_addr)->sin_port));
      break;
    }
  }

  return rc;
#endif
}

int
real_open (const char *pathname, int flags, mode_t mode)
{
#if IN_RTLD
  return open (pathname, flags, mode);
#else
  return syscall (SYS_open, pathname, flags, mode);
#endif
}

int
real_stat (const char *path, struct stat *buf)
{
#if IN_RTLD
  return stat (path, buf);
#else
  return syscall (SYS_stat, path, buf);
#endif
}

int
real_lstat (const char *path, struct stat *buf)
{
#if IN_RTLD
  return lstat (path, buf);
#else
  return syscall (SYS_lstat, path, buf);
#endif
}

int
real_stat64 (const char *path, struct stat64 *buf)
{
#if IN_RTLD
  return stat64 (path, buf);
#else
  return syscall (SYS_stat64, path, buf);
#endif
}

int
real_lstat64 (const char *path, struct stat64 *buf)
{
#if IN_RTLD
  return lstat64 (path, buf);
#else
  return syscall (SYS_lstat64, path, buf);
#endif
}

int
real_unlink (const char *path)
{
#if IN_RTLD
  assert (0); // ld.so does not use unlink
  return -1;
#else
  return syscall (SYS_unlink, path);
#endif
}

int
real_rmdir (const char *path)
{
#if IN_RTLD
  assert (0);
  return -1;
#else
  return syscall (SYS_rmdir, path);
#endif
}

int
real_dup (int fd)
{
#if IN_RTLD
  assert (0);
  return -1;
#else
  return syscall (SYS_dup, fd);
#endif
}
