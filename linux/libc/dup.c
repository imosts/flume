

#include "flume_features.h"
#include "flume_alias.h"
#include <sys/types.h>

int __dup (int fd);

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
__dup (int fd)
{
  if (flume_libc_interposing ()) {
    if (fd < 0) {
      flume_set_errno (EINVAL);
      return -1;
    }
    return flume_dup (fd);
  } else {
    return real_dup (fd);
  }
}

flume_all_aliases (dup);
