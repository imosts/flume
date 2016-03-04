#include "flume_features.h"
#include "flume_alias.h"

#include <fcntl.h>
#include <stdarg.h>
#include <stddef.h>
#include <sys/types.h>
#include <sys/socket.h>

#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_internal.h"

int ___socket (int domain, int type, int protocol)
{
  int rc;

  if (flume_libc_interposing ()) 
    rc = flume_socket (domain, type, protocol);
  else
    rc = real_socket (domain, type, protocol);

  return rc;
}

strong_alias (___socket, socket);
strong_alias (___socket, __socket);
