
/*
 * Routines shared internally by flume libraries
 *
 */

#include "flume_api.h"
#include "flume_prot.h"

#ifndef _FLUME_INTERNAL_H_
#define _FLUME_INTERNAL_H_

#define FLUME_ATOI_ERROR -1
#define FLUME_NO_ENV_ERROR -2

int rpc_call_fd (int proc, void *in, void *out, const char *cmd, int *outfd);
int rpc_call (int proc, void *in, void *out, const char *cmd);

int my_env2num (const char *k);
int my_str2num (const char *in);

void set_fd_status (int fd, fd_typ_t st);
void fds_init ();
int is_open_flume_socket (int fd);
int register_fd (int fd, const x_handle_t h);

/* Real syscalls: can be called from within linker or libc */
int real_socket (int domain, int type, int protocol);
int real_connect (int sockfd, const struct sockaddr *serv_addr, 
                  socklen_t attrlen);
int real_open (const char *pathname, int flags, mode_t mode);
int real_stat (const char *path, struct stat *buf);
int real_lstat (const char *path, struct stat *buf);
int real_stat64 (const char *path, struct stat64 *buf);
int real_lstat64 (const char *path, struct stat64 *buf);
int real_unlink (const char *path);
int real_rmdir (const char *path);
int real_dup (int fd);

#endif /* _FLUME_INTERNAL_H_ */
