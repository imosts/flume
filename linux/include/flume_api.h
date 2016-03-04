#ifndef _FLUME_API_H_
#define _FLUME_API_H_

#include "flume_features.h"

#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/socket.h>
#include "flume_libc_stubs.h"
#include <stdint.h>

typedef enum { FD_CLOSED = 0, FD_SOCKET = 1, FD_FILE = 2 } fd_typ_t;

int flume_open_simple (const char *path, int flags, int mode);

int flume_close(int d);
int flume_utimes (const char *path, const struct timeval *tv);
int flume_close (int fd);
int flume_unlink(const char *path);
int flume_mkdir (const char *path, mode_t mode);
int flume_rmdir (const char *path);
int flume_link (const char *n1, const char *n2);
int flume_chmod (const char *file, mode_t mode);
int flume_rename (const char *from, const char *to);
int flume_symlink (const char *from, const char *to);
int flume_readlink (const char *from, char *out, size_t bufsiz);
int flume_stat (const char *path, struct stat *sb);
int flume_lstat (const char *path, struct stat *sb);
int flume_null ();
int flume_debug_msg (const char *s);
int flume_socket (int domain, int type, int protocol);
int flume_connect (int sockfd, const struct sockaddr *serv_addr, 
                   socklen_t attrlen);
int flume_dup (int fd);
int flume_dup_ctl_sock (void);

pid_t flume_getpid_from_rm (void);
void flume_clear_pid (void);

#ifdef _LARGEFILE64_SOURCE
int flume_stat64 (const char *path, struct stat64 *sb);
int flume_lstat64 (const char *path, struct stat64 *sb);
int flume_xstat64 (int vers, const char *file, struct stat64 *buf);
int flume_lxstat64 (int vers, const char *file, struct stat64 *buf);
#endif

int flume_access (const char *path, int mode);

int flume_execve (const char *path, char *const argv[], char *const envp[]);
int flume_execvp (const char *path, char *const argv[]);

int flume_waitpid_common (uint64_t *pidout, int *visible, 
			  int *status, unsigned long long flmpid, int options);

/*For use to bootstrap yourself into the flume space. */
int bootstrap_execve (const char *realpath, char *const argv[], 
		      char *const envp[]);

int unixsocket_connect_c (const char *path);

int   flume_myctlsock ();
void  flume_setctlsock (int fd);
int   connected_to_flume ();
int   confined ();
int   flume_set_libc_interposing (int v);
int   flume_libc_interposing ();

int flume_xstat (int vers, const char *file, struct stat *buf);
int flume_lxstat (int vers, const char *file, struct stat *buf);

int flume_get_flm_errno ();
const char *flume_get_errstr ();
void flume_set_flm_errno(int s);
void flume_set_err (int c, const char *s);
void flume_set_errstr (const char *i);


#define FLUME_SET_ERRNO(e) \
do { \
  flume_set_err (e, NULL); \
} while (0)

#define FLUME_SET_ERRNO_STR(e,s) \
do { \
  flume_set_err (e, s); \
} while (0)

#define FLUME_SET_ERRNO_UNION(x) \
do { \
  flume_set_err (x.status, NULL); \
  if (flume_get_flm_errno () == FLUME_EPERM) { \
    flume_set_errstr (x.u.eperm.desc); \
  }  \
} while (0) 


#endif /* _FLUME_API_H_ */
