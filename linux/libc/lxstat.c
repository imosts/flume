

#include "flume_features.h"
#include "flume_alias.h"
#include <sys/stat.h>

int __lxstat (int vers, const char *file, struct stat *buf);

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
__lxstat (int vers, const char *file, struct stat *buf)
{
  if (vers != _STAT_VER || file == NULL || buf == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  if (flume_libc_interposing ())
    return flume_lstat (file, buf);
  else
    return real_lstat (file, buf);
}

flume_all_aliases (lxstat);
