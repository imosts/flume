

#include "flume_features.h"
#include "flume_alias.h"
#include <sys/types.h>

int __chmod (const char *file, mode_t mode);

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
__chmod (const char *file, mode_t mode)
{
  if (file == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  return flume_chmod (file, mode);
}

weak_alias (__chmod, chmod);
