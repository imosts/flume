
#include "flume_features.h"
#include "flume_alias.h"

int __open (const char *file, int oflag, ...);
strong_alias (__open, open);
strong_alias (__open, __libc_open);
strong_alias (__open, __libc_open64);
strong_alias (__open, __GI___open);
strong_alias (__open, __open_nocancel);
strong_alias (__open, __open64);
strong_alias (__open, open64);
strong_alias (__open, __GI___open64);


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
__open (const char *file, int oflag, ...)
{
  int mode = 0;
  if (file == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  if (oflag & O_CREAT) {
    va_list arg;
    va_start (arg, oflag);
    mode = va_arg (arg, int);
    va_end (arg);
  }
  
  if (flume_libc_interposing ())
    return flume_open_simple (file, oflag, mode);
  else
    return real_open (file, oflag, mode);
}

