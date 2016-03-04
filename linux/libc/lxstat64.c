

#include "flume_features.h"
#include "flume_alias.h"
#include <sys/stat.h>

int __lxstat64 (int vers, const char *file, struct stat64 *buf);

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
___lxstat64 (int vers, const char *file, struct stat64 *buf)
{
  if (vers != _STAT_VER || file == NULL || buf == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  if (flume_libc_interposing ())
    return flume_lstat64 (file, buf);
  else
    return real_lstat64 (file, buf);
}

weak_alias (___lxstat64, __lxstat64);
flume_all_aliases (lxstat64);

// only do this for 32 bit machines
#if __WORDSIZE == 32
versioned_symbol(libc, ___lxstat64, __lxstat64, GLIBC_2.2);
#endif
