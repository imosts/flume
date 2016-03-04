

#include "flume_features.h"
#include "flume_alias.h"

int __link (const char *from, const char *to);

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
__link (const char *from, const char *to)
{
  if (from == NULL || to == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  return flume_link (from, to);
}

weak_alias (__link, link);
