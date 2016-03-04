

#include "flume_features.h"
#include "flume_alias.h"

int __rmdir (const char *path);

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
__rmdir (const char *path)
{
  if (path == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }

  if (flume_libc_interposing ())
    return flume_rmdir (path);
  else
    return real_rmdir (path);
}

weak_alias (__rmdir, rmdir);
