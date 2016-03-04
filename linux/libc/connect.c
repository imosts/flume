
#include "flume_features.h"
#include "flume_alias.h"

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stddef.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <unistd.h>

#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_internal.h"

int __connect (int sockfd, const struct sockaddr *serv_addr, 
               socklen_t attrlen)
{
  int rc;

  if (flume_libc_interposing ()) 
    rc = flume_connect (sockfd, serv_addr, attrlen);
  else
    rc = real_connect (sockfd, serv_addr, attrlen);
           
  return rc;
}

strong_alias (__connect, connect);
strong_alias (__connect, __connect_internal);
strong_alias (__connect, __libc_connect);
