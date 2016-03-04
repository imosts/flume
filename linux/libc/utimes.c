

#include "flume_features.h"
#include "flume_alias.h"
#include <sys/time.h>
#include <sys/types.h>

int __utime (const char *file, const struct timeval tvp[2]);

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
__utimes (const char *file, const struct timeval tvp[2])
{
  if (file == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  return flume_utimes (file, tvp);
}

weak_alias (__utimes, utimes);

