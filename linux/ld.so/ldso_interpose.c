
#include "flume_features.h"

#include <stdlib.h>
#include <limits.h>
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/time.h>
#include <errno.h>
#include <assert.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <netinet/tcp.h>
#include <unistd.h>

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_internal.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_alias.h"

extern int __orig_open (const char *file, int flags, int mode);
extern int __orig_access (const char *file, int flags);
extern int __orig_xstat64 (int v, const char *b, struct stat64 *st);
extern pid_t __orig_getpid (void);

int 
__interpose_flume_ld_so_open (const char *file, int oflag, ...)
{
  int mode = 0;
  if (oflag & O_CREAT) {
    va_list arg;
    va_start (arg, oflag);
    mode = va_arg (arg, int);
    va_end (arg);
  }

  /* Linker always uses flume open when connected */
  if (connected_to_flume())
    return flume_open_simple (file, oflag, mode);
  else
    return __orig_open (file, oflag, mode);
}

int
__interpose_flume_ld_so_access (const char *file, int flags)
{
  /* Linker always uses flume access when connected */
  if (connected_to_flume ()) {
    return flume_access (file, flags);
  } else {
    return __orig_access (file, flags);
  }
}


int
__interpose_flume_ld_so_xstat64 (int v, const char *file, struct stat64 *buf)
{
  /* Linker always uses flume stat when connected */
  if (connected_to_flume ()) {
    return flume_stat64 (file, buf);
  } else {
    return __orig_xstat64 (v, file, buf);
  }
}

pid_t
__interpose_flume_ld_so_getpid(void)
{
  pid_t ret;
  if ((ret = __orig_getpid()) < 0)
    ret = FLUME_FAKE_PID;
  return ret;
}

strong_alias (__interpose_flume_ld_so_open, flume_ld_so_open);
strong_alias (__interpose_flume_ld_so_access, flume_ld_so_access);
strong_alias (__interpose_flume_ld_so_xstat64, flume_ld_so_xstat64);
strong_alias (__interpose_flume_ld_so_getpid, flume_ld_so_getpid);

