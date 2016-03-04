
/**
 * This file contains functions that libc uses to talk to RM.
 */

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

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_internal.h"
#include "flume_libc_stubs.h"

static int _flume_debug_level;
static int _flume_got_debug_level;
static int _flume_libc_interposing = 1;
static int _flume_libc_interposing_checked_env = 0;

#define CLEAR(x) memset (&x, 0, sizeof (x))

#include <paths.h>


int
flume2errno (int i)
{
  switch (i) {
  case FLUME_EPERM: return EPERM;
  case FLUME_EPATH: return EINVAL;
  case FLUME_EAGAIN: return EAGAIN;
  case FLUME_EXDEV: return EXDEV;
  case FLUME_EINVAL: return EINVAL;
  case FLUME_ENOENT: return ENOENT;
  case FLUME_EISDIR: return EISDIR;
  case FLUME_EEXIST: return EEXIST;
  default: 
    FLUME_DEBUG2 (FLUME_DEBUG_LIBC,
		 "WARNING unhandled flume_errno " FLUME_PRId 
		 ", using EIO instead\n", FLUME_PRId_ARG(i));
    return EIO;
  }
}

/*
 * Return true if this process has a ctlsock.
 */
int 
connected_to_flume()
{
  return (flume_myctlsock () >= 0);
}

/*
 * Return true if libc should send syscalls through flume.
 *  (An unconfined process can decide when syscalls should go
 *  through RM to support legacy code that is unaware of flume
 *  syscalls)
 */
int
flume_libc_interposing ()
{
  if (!_flume_libc_interposing_checked_env) {
    char *s = getenv (FLUME_INTERPOSING_INITIAL_EV);
    if (s) {
      if (!strcmp (s, FLUME_NO)) {
        _flume_libc_interposing = 0;
      } else if (!strcmp (s, FLUME_YES)) {
        _flume_libc_interposing = 1;
      } else {
        FLUME_ERROR_PRINTF ("%s: invalid value '%s', should be '%s' or '%s', setting libc_interpose=1\n", 
                            FLUME_INTERPOSING_INITIAL_EV, s, FLUME_YES, FLUME_NO);
        _flume_libc_interposing = 1;
      }
    }
    _flume_libc_interposing_checked_env = 1;
  }
  return (confined () || _flume_libc_interposing);
}

/*
 * Return true if this process is forcibly confined.
 */
int
confined ()
{
  char *s = getenv (FLUME_CONFINED_EV);
  return (s && !strcmp (s, FLUME_YES));
}

int
flume_set_libc_interposing (int v)
{
  if (!connected_to_flume ()) {
    return -1;
  } else if (confined () && !v) {
    return -1;
  } else {
    _flume_libc_interposing = v;
    return 0;
  }
}


static int 
get_debug_lev ()
{
  int i;

  if (!_flume_got_debug_level) {
    _flume_got_debug_level = 1;

    /* set debug flags for the whole program */
    i = my_env2num (FLUME_DBG_EV);
    if (i >= 0) {
      _flume_debug_level = i;
      FLUME_ERROR_PRINTF ("pid %u set %s=%x\n", 34, 
			 FLUME_DBG_EV, _flume_debug_level);
    } else if (i == -1) {
      FLUME_ERROR_PRINTF ("%s: atoi error\n", FLUME_DBG_EV);
    }
  }
  return _flume_debug_level;
}

int flume_do_debug (int i) { 
  return (get_debug_lev () & i);
}

/*
 *  Replacements for libc syscalls
 */

static void
init_arg (file_arg_t *arg)
{
  memset (arg, 0, sizeof (*arg));
}

static void
init_res (file_res_t *res)
{
  memset (res, 0, sizeof (*res));
}

static int
do_call (int procno, file_arg_t *arg, int getfd, const char *desc)
{
  int rc;
  int fd;

  file_res_t res;
  init_res (&res);

  rc = rpc_call_fd (procno, arg, &res, desc, getfd ? &fd : NULL);
  if (rc == 0) {
    if (res.status != FLUME_OK) {
      rc = -1;
      FLUME_SET_ERRNO_UNION (res);
      flume_set_errno (flume2errno (res.status));
    } else if (getfd) {
      rc = fd;
    }
  }

  xdr_free ((xdrproc_t) xdr_file_res_t, (char *) &res);
  return rc;
}

static int
call_open_RPC (file_arg_t *arg, char *outpath)
{
  int rc;
  int l;
  file_res_t res;
  init_res (&res);
  int fd;

  rc = rpc_call_fd (OPEN_FILE, arg, &res, "open", &fd);
  if (rc == 0) {
    if (res.status != FLUME_PATH_OK) {
      rc = -1;
      FLUME_SET_ERRNO_UNION (res);
      flume_set_errno (flume2errno (res.status));
    } else {
      rc = fd;
      if (outpath) {
	l = strlen (res.u.path);
	memcpy (outpath, res.u.path, l);
	outpath[l] = 0;
      } else {
	/* otherwise, foggedaboutit */
      }
    }
  }

  xdr_free ((xdrproc_t) xdr_file_res_t, (char *) &res);
  return rc;
}

int flume_mkdir (const char *path, mode_t mode)
{
  file_arg_t arg;
  int rc;

  init_arg (&arg);
  arg.c_args.path = (char *)path;
  arg.c_args.mode = mode;

  rc = do_call (FLUME_MKDIR, &arg, 0, "mkdir");
  FLUME_DEBUG2 (FLUME_DEBUG_LIBC, 
	       "flume_mkdir(%s) => " FLUME_PRId "\n", 
	       path, FLUME_PRId_ARG(rc));
  return rc;
}

int flume_rmdir (const char *path)
{
  file_arg_t arg;
  int rc;

  init_arg (&arg);
  arg.c_args.path = (char *)path;
  rc = do_call (FLUME_RMDIR, &arg, 0, "rmdir");
  FLUME_DEBUG (FLUME_DEBUG_LIBC, stderr, 
	      "flume_rmdir(%s) => " FLUME_PRId "\n", 
	      path, FLUME_PRId_ARG(rc) );
  return rc;
}

static int real_close (int fd)
{
#ifndef IN_RTLD 
  return syscall (SYS_close, fd);
#else /* !IN_RTLD */
  return -1;
#endif /* IN_RTLD */
}

int flume_close (int fd)
{
  int rc1 = 0;
  int rc2 = 0;
  int rc;
  flume_status_t tc;


  if (is_open_flume_socket (fd)) {
  
    rc1 = rpc_call (FLUME_CLOSE, &fd, &tc, "close");
    if (rc1 == 0) {
      if (tc != FLUME_OK) {
	rc1 = -1;
	flume_set_errno (flume2errno (tc));
      }
    }
	set_fd_status (fd, FD_CLOSED);
  }
  rc2 = real_close (fd);

  rc = (rc1 < 0) ? rc1 : rc2;

  FLUME_DEBUG (FLUME_DEBUG_LIBC, stderr,
  	"flume_close(" FLUME_PRId ") => " FLUME_PRId "\n",
		FLUME_PRId_ARG(fd), FLUME_PRId_ARG (rc));

  return rc;
}

//
// Like dup(2) -- duplicate a file descriptor.
//
int flume_dup (int fd)
{
  int rc = 0;
  flume_dup_arg_t arg;
  flume_status_t res;

  CLEAR (arg);
  
#ifndef IN_RTLD
  rc = syscall (SYS_dup, fd);
#endif /* IN_RTLD */

  if (rc < 0) {
    FLUME_DEBUG2 (FLUME_DEBUG_LIBC, 
		  "in flume_dup: dup(" FLUME_PRId ") => " FLUME_PRId "\n",
		  FLUME_PRId_ARG(fd), FLUME_PRId_ARG (rc));
  } else {
    if (is_open_flume_socket (fd)) {
      arg.fd_orig = fd;
      arg.fd_copy = rc;
      if (rpc_call (FLUME_DUP, &arg, &res, "dup") < 0) {
	/* noop */
      } else if (res != FLUME_OK) {
	flume_set_errno (flume2errno (res));
	real_close (rc);
	rc = -1;
      } else {
	set_fd_status (rc, FD_SOCKET);
      }
    }
  }
  FLUME_DEBUG2 (FLUME_DEBUG_LIBC, 
	       "flume_dup(" FLUME_PRId ") => " FLUME_PRId "\n",
		FLUME_PRId_ARG (fd), FLUME_PRId_ARG (rc));
  return rc;
}


#define M(f) out->st_##f = in->f                     
#define ALL()                                         \
  M(dev);                                             \
  M(ino);                                             \
  M(mode);                                            \
  M(nlink);                                           \
  M(uid);                                             \
  M(gid);                                             \
  M(rdev);                                            \
  M(atime);                                           \
  M(mtime);                                           \
  M(ctime);                                           \
  M(size);                                            \
  M(blocks);                                          \
  M(blksize);

static void
xdr2stat_c (struct stat *out, const x_stat_t *in)
{
  memset ((void *)out, 0, sizeof (*out));
  ALL();
}

#ifdef _LARGEFILE64_SOURCE
static void
xdr2stat64_c (struct stat64 *out, const x_stat_t *in)
{
  memset ((void *)out, 0, sizeof (*out));
  ALL();
}
#endif

#undef M
#undef ALL

static int
_flume_stat (const char *path, struct stat *sb, int use_lstat)
{
  file_arg_t arg;
  file_res_t res;
  int rc;
  int proc;
  CLEAR (arg);
  CLEAR (res);
  arg.c_args.path = (char *)path;

  proc = use_lstat ? FLUME_LSTAT_FILE : FLUME_STAT_FILE;
  if ((rc = rpc_call (proc, &arg, &res, "stat/lstat")) < 0) {
    /* noop */
  } else if (res.status == FLUME_STAT_OK) {
    xdr2stat_c (sb, &res.u.stat);
  } else {
    rc = -1;
    flume_set_errno (flume2errno (res.status));
    FLUME_SET_ERRNO_UNION (res);
  }
  return rc;
}

#ifdef _LARGEFILE64_SOURCE
static int
_flume_stat64 (const char *path, struct stat64 *sb, int use_lstat)
{
  file_arg_t arg;
  file_res_t res;
  int rc;
  int proc;
  CLEAR (arg);
  CLEAR (res);
  arg.c_args.path = (char *)path;

  proc = use_lstat ? FLUME_LSTAT_FILE : FLUME_STAT_FILE;
  if ((rc = rpc_call (proc, &arg, &res, "stat/lstat")) < 0) {
    /* noop */
  } else if (res.status == FLUME_STAT_OK) {
    xdr2stat64_c (sb, &res.u.stat);
  } else {
    rc = -1;
    flume_set_errno (flume2errno (res.status));
    FLUME_SET_ERRNO_UNION (res);
  }
  return rc;
}
#endif

int
flume_access (const char *path, int mode)
{
  file_arg_t arg;
  file_res_t res;
  int rc;
  CLEAR (arg);
  CLEAR (res);
  arg.c_args.path = (char *)path;
  arg.c_args.mode = mode;

  if ((rc = rpc_call (FLUME_ACCESS_FILE, &arg, &res, "access")) < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    rc = -1;
    flume_set_errno (flume2errno (res.status));
    FLUME_SET_ERRNO_UNION (res);
  }
  FLUME_DEBUG2(FLUME_DEBUG_LIBC, 
	      "flume_access(%s," FLUME_PRId ") => " FLUME_PRId "\n", 
	      path, FLUME_PRId_ARG(mode), FLUME_PRId_ARG (rc));
  return rc;
}


int flume_stat (const char *path, struct stat *sb)
{
  return _flume_stat (path, sb, 0);
}

int flume_lstat (const char *path, struct stat *sb)
{
  return _flume_stat (path, sb, 1);
}

#ifdef _LARGEFILE64_SOURCE
int flume_stat64 (const char *path, struct stat64 *sb)
{
  return _flume_stat64 (path, sb, 0);
}

int flume_lstat64 (const char *path, struct stat64 *sb)
{
  return _flume_stat64 (path, sb, 1);
}
#endif

int flume_readlink (const char *in, char *out, size_t bufsize)
{
  file_arg_t arg;
  file_res_t res;
  int rc;
  size_t bytes;
  bufsize --;

  CLEAR (arg);
  CLEAR (res);
  arg.c_args.path = (char *)in;
  if ((rc = rpc_call (FLUME_READLINK, &arg, &res, "readlink")) < 0) {
    /* noop */
  } else if (res.status == FLUME_PATH_OK) {
    memset (out, 0, bufsize);
    bytes = strlen (res.u.path);
    if (bytes > bufsize) bytes = bufsize;
    memcpy (out, res.u.path, bytes);
    FLUME_DEBUG (FLUME_DEBUG_LIBC, stderr, 
		"flume_readlink(%s) => %s\n", in, out);
    rc = bytes;
  } else {
    FLUME_SET_ERRNO_UNION (res);
    flume_set_errno (flume2errno (res.status));
    rc = -1;
  }
  xdr_free ((xdrproc_t) xdr_file_res_t, (char *) &res);

  return rc;
}


int flume_link (const char *name1, const char *name2)
{
  file_arg_t arg;
  int rc;

  init_arg (&arg);
  arg.c_args.path = (char *)name2;
  arg.c_args.path_src = (char **)&name1;
  rc = do_call (FLUME_LINK, &arg, 0, "link");
  FLUME_DEBUG (FLUME_DEBUG_LIBC, stderr, 
	      "flume_link(%s,%s) => " FLUME_PRId "\n", 
	      name1, name2, FLUME_PRId_ARG(rc));
  return rc;
}

/* 
 * must give flume_open2 a buffer of size PATH_MAX for first
 * argument!
 */
int
flume_open_full (char *outpath, const char *path, int flags, int mode, 
		x_labelset_t *ls, x_labelset_t *ep)
{
  int rc; 

  file_arg_t arg;
  init_arg (&arg);
  arg.c_args.path = (char *)path;
  arg.c_args.flags = flags;
  arg.c_args.mode = mode;
  arg.c_args.data.len = 0;
  arg.c_args.data.val = NULL;
  arg.xls = ls;
  arg.ep = ep;

  rc = call_open_RPC (&arg, outpath);

  if (rc >= 0) {
    set_fd_status (rc, FD_FILE);
  }

  FLUME_DEBUG2(FLUME_DEBUG_LIBC, 
	      "flume_open(%s) => " FLUME_PRId "\n", 
	      path, FLUME_PRId_ARG (rc));

  return rc;
}

int flume_open (const char *path, int flags, int mode,
	       x_labelset_t *ls, x_labelset_t *ep)
{
  return flume_open_full (NULL, path, flags, mode, ls, ep);
}


int flume_open_simple (const char *path, int flags, int mode)
{
  return flume_open_full (NULL, path, flags, mode, NULL, NULL);
}


int flume_unlink(const char *path){
  
  int rc;
  file_arg_t arg;
  init_arg (&arg);
  arg.c_args.path = (char *)path;

  rc = do_call (FLUME_UNLINK_FILE, &arg, 0, "unlink");
  FLUME_DEBUG2 (FLUME_DEBUG_LIBC, 
	       "unlink(%s) => " FLUME_PRId "\n", 
	       path, FLUME_PRId_ARG(rc));
  return rc;
}

/**
 * Returns 0 on success, or something negative on error.  Flume rename
 * cannot move files 
 */
int flume_rename(const char* from, const char* to){
  file_arg_t arg;
  int rc;

  init_arg (&arg);
  arg.c_args.path = (char *) to;
  arg.c_args.path_src = (char **) &from;
  rc = do_call (FLUME_RENAME, &arg, 0, "rename");
  FLUME_DEBUG2 (FLUME_DEBUG_LIBC,
	      "flume_rename(%s, %s) => " FLUME_PRId "\n", 
	       from, to, FLUME_PRId_ARG(rc));
  return rc;

}


/**
 * Returns 0 on success, or something negative on error.  
 */
int flume_symlink_full (const char* contents, const char* newfile,
		       const x_labelset_t *ls){
  file_arg_t arg;
  int rc;

  init_arg (&arg);
  arg.c_args.path = (char *) newfile;
  arg.c_args.path_src = (char **) &contents;
  arg.xls = (x_labelset_t *) ls;
  rc = do_call (FLUME_SYMLINK, &arg, 0, "symlink");
  FLUME_DEBUG2 (FLUME_DEBUG_LIBC,
	      "flume_symlink(%s, %s) => " FLUME_PRId "\n", 
	       contents, newfile, FLUME_PRId_ARG(rc));
  return rc;

}

int
flume_symlink (const char *contents, const char *newfile)
{
  return flume_symlink_full (contents, newfile, NULL);
}

static void
timeval2xdr (x_timeval_t *out, const struct timeval *in)
{
  out->tv_sec = in->tv_sec;
  out->tv_usec = in->tv_usec;

}

/*
 * the utimes(2) syscall.
 */
int
flume_utimes (const char *path, const struct timeval *tv)
{
  file_arg_t arg;
  init_arg (&arg);
  arg.c_args.path = (char *)path;
  x_utimes_t ut;
  if (tv) {
    timeval2xdr (&ut.atime, &tv[0]);
    timeval2xdr (&ut.mtime, &tv[1]);
    arg.c_args.utimes = &ut;
  }
  int rc = do_call (FLUME_UTIMES, &arg, 0, "utimes");
  FLUME_DEBUG2(FLUME_DEBUG_LIBC, 
	      "utimes(%s) => " FLUME_PRId "\n", 
	      path, FLUME_PRId_ARG(rc));
  return rc;
}

/*
 * the chmod(2) syscall.
 */
int
flume_chmod (const char *path, mode_t mode)
{
  int rc = 0;
  FLUME_DEBUG2(FLUME_DEBUG_LIBC, 
	     "chmod(%s) UNIMPLEMENTED! => " FLUME_PRId "\n", 
	      path, FLUME_PRId_ARG (rc));
  return rc;
}


int
flume_dup_ctl_sock (void)
{
  flume_status_t res;
  int rc = -1;
  int fd;

  CLEAR (res);

  if ((rc = rpc_call_fd (FLUME_DUP_CTL_SOCK, NULL, 
			 &res, "dup_ctl_socket", &fd)) < 0) {
    /* noop */
  } else if (res != FLUME_OK) {
    rc = -1;
    FLUME_SET_ERRNO(res);
  } else {
    set_fd_status (fd, FD_SOCKET);
    rc = fd;
  }
  return rc;
}

int
flume_waitpid_common (uint64_t *pidout, 
		      int *visible,
		      int *exit_code, 
		      unsigned long long flmpid, int options)
{
  flume_wait_arg_t arg;
  flume_wait_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);

  if (flmpid == 0) {
    arg.which.typ = FLUME_WAIT_ANY;
  } else {
    arg.which.typ = FLUME_WAIT_ONE;
    arg.which.u.flmpid = flmpid;
  }
  arg.options = options;

  if ((rc = rpc_call (FLUME_WAIT, &arg, &res, "wait")) < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    rc = -1;
    FLUME_SET_ERRNO_UNION (res);
  } else {
    *pidout = res.u.exit.flmpid;
    if (res.u.exit.exit_status.status == FLUME_CHILD_EXITTED) {
      *visible = 1;
      *exit_code = res.u.exit.exit_status.u.exit_code;
    } else {
      *visible = 0;
    }
    rc = 0;
  }
  xdr_free ((xdrproc_t) xdr_flume_wait_res_t, (char *) &res);
  return rc;
}


pid_t
flume_getpid_from_rm (void)
{
  int rc;
  getpid_res_t res;
  CLEAR (res);
  pid_t out = -1;

  FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "calling getpid_from_rm\n");

  rc = rpc_call (FLUME_GETPID, NULL, &res, "flume_getpid");
  if (res.status != FLUME_OK) {
    FLUME_SET_ERRNO_UNION (res);
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_getpid: Error response: %d\n", rc);
  } else {
    out = res.u.pid;
  }
  xdr_free ((xdrproc_t )xdr_getpid_res_t, (char *)&res);
  return out;
}

static pid_t my_pid;
static int my_pid_init;

void
flume_clear_pid (void)
{
  my_pid_init = 0;
}

pid_t
flume_getpid_canfail ()
{
  if (!my_pid_init) return FLUME_FAKE_PID;
  else return my_pid;
}

#ifdef IN_RTLD

pid_t
flume_getpid ()
{
  return FLUME_FAKE_PID;
}

#else 

pid_t
flume_getpid ()
{
  pid_t ret = FLUME_FAKE_PID;
  if (!my_pid_init) {
    pid_t p = syscall (SYS_getpid);
    if (p < 0) {
      p = flume_getpid_from_rm ();
    }
    if (p >= 0) {
      ret = my_pid = p;
      my_pid_init = 1;
    }
  } else {
    ret = my_pid;
  }
  return ret;
}

#endif /* IN_RTLD */

int 
flume_socket (int domain, int type, int protocol)
{
  int fd, rc = -1;
  file_res_t res;

  CLEAR (res);


  if (domain != AF_UNIX) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                   "flume_socket: unsupported domain\n");
      FLUME_SET_ERRNO(FLUME_ERR);
  } else if (type != SOCK_STREAM) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                   "flume_socket: unsupported type\n");
      FLUME_SET_ERRNO(FLUME_ERR);
  } else if (protocol != 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                   "flume_socket: unsupported protocol\n");
      FLUME_SET_ERRNO(FLUME_ERR);

  } else if (rpc_call_fd (FLUME_SOCKET, NULL, &res,
                   "flume_socket", &fd) < 0) {
    /* noop */
  } else if (res.status != FLUME_FDPASS_OK_OPAQUE) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                 "flume_socket: non-ok response from "
                 "FLUME_SOCKET RPC %d \n", res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    if (fd < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                   "flume_socket: error receiving fd\n");
      FLUME_SET_ERRNO(FLUME_ERR);
    } else if (register_fd (fd, res.u.opaque_h) < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                   "flume_socket: error registering "
                   "fd %d with RM \n", fd);
      FLUME_SET_ERRNO(FLUME_ERR);
    } else {
      rc = fd;
      set_fd_status (fd, FD_SOCKET);
    }
  }

  FLUME_DEBUG2(FLUME_DEBUG_LIBC, 
	      "flume_socket(%d,%d,%d) => " FLUME_PRId "\n", 
	      domain, type, protocol, FLUME_PRId_ARG (rc));
  return rc;
}

int
flume_connect (int sockfd, const struct sockaddr *serv_addr, 
               socklen_t attrlen)
{
  int rc = -1;
  connect_arg_t arg;
  file_res_t res;
  struct sockaddr_un *sun = (struct sockaddr_un *) serv_addr;
  char *path = "";

  CLEAR (arg);

  arg.fd = sockfd;
  arg.c_args.path = (char *) sun->sun_path;

  if (!sun) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                   "flume_connect: null address\n");
      FLUME_SET_ERRNO(FLUME_ERR);
  } else if (sun->sun_family != AF_UNIX) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                   "flume_connect: invalid address family %d != %d\n",
                   sun->sun_family, AF_UNIX);
      FLUME_SET_ERRNO(FLUME_ERR);

  } else if (rpc_call (FLUME_CONNECT, &arg, &res, 
                "flume_connect") < 0) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                 "flume_connect: error connecting fd %d to %s\n", 
                 arg.fd, arg.c_args.path);
    FLUME_SET_ERRNO(FLUME_ERR);
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                 "flume_connect: non-ok response from "
                 "FLUME_CONNECT RPC %d \n", res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    rc = 0;
    set_fd_status (arg.fd, FD_SOCKET);
  }

  path = sun->sun_path;
  FLUME_DEBUG2(FLUME_DEBUG_LIBC, 
	      "flume_connect(%s) => " FLUME_PRId "\n", 
	      path, FLUME_PRId_ARG (rc));

  return rc;
}
