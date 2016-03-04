
/*
 * copied from Plash, src/libpthread-extras.c
 */

#include <sys/types.h>
#include <sys/socket.h>

#define weak_alias(name, aliasname) \
  extern int aliasname() __attribute ((weak, alias (#name)));

int __libc_open(const char *filename, int flags, int mode);
int __libc_open64(const char *filename, int flags, int mode);
int __libc_connect(int sockfd, const struct sockaddr *serv_addr, 
                   socklen_t attrlen);
int __libc_close(int fd);

int __open(const char *filename, int flags, int mode)
{
  return __libc_open(filename, flags, mode);
}

int __open64(const char *filename, int flags, int mode)
{
  return __libc_open64(filename, flags, mode);
}

int __connect(int sockfd, const struct sockaddr *serv_addr, 
              socklen_t attrlen)
{
  return __libc_connect(sockfd, serv_addr, attrlen);
}

int __close(int fd)
{
   return __libc_close (fd);
}

weak_alias(__open, open)
weak_alias(__open64, open64)
weak_alias(__close, close);
weak_alias(__open, __open_nocancel);
weak_alias(__connect, connect);
weak_alias(__connect, __connect_internal);
