

#include "flume_features.h"
#include "flume_alias.h"
#include <unistd.h>

int __access (const char *file, int type);

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
__access (const char *file, int type)
{
  if (file == NULL || (type & ~(R_OK|W_OK|X_OK|F_OK)) != 0) {
    flume_set_errno (EINVAL);
    return -1;
  }
  return flume_access (file, type);
}

weak_alias (__access, access);
