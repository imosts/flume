

#include "flume_features.h"
#include "flume_alias.h"

int __close (int fd);

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stddef.h>

#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_internal.h"

int 
__close (int fd)
{
  if (fd < 0) {
    flume_set_errno (EBADF);
    return -1;
  }
  return flume_close (fd);
}

flume_all_aliases (close);
