

#include "flume_features.h"
#include "flume_alias.h"
#include <sys/stat.h>

int __xstat64 (int vers, const char *file, struct stat64 *buf);

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

// Code stolen from ./sysdeps/unix/sysv/linux/xstat64.c

/* The variable is shared between all wrappers around *stat64 calls.
   This is the definition.  */
int __have_no_stat64;


int 
___xstat64 (int vers, const char *file, struct stat64 *buf)
{
  if (vers != _STAT_VER || file == NULL || buf == NULL) {
    flume_set_errno (EINVAL);
    return -1;
  }
  if (flume_libc_interposing ())
    return flume_stat64 (file, buf);
  else
    return real_stat64 (file, buf);
}

weak_alias (___xstat64, __xstat64);
flume_all_aliases (xstat64);

// only do this on 32-bit machines
#if __WORDSIZE == 32
versioned_symbol(libc, ___xstat64, __xstat64, GLIBC_2.2);
#endif
