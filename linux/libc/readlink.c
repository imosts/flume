

#include "flume_features.h"
#include "flume_alias.h"
#include <sys/types.h>

int __readlink (const char *file, char *buf, size_t len);

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
__readlink (const char *file, char *buf, size_t len)
{
  if (file == NULL || buf == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  return flume_readlink (file, buf, len);
}

weak_alias (__readlink, readlink);
