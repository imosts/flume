

#include "flume_features.h"
#include "flume_alias.h"
#include <unistd.h>
#include <sys/types.h>
#include <sys/syscall.h>

pid_t __getpid (void);

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
#include "flume_pid.h"

pid_t
__getpid (void)
{
  return flume_getpid ();
}

weak_alias (__getpid, getpid);
weak_alias (__getpid, __GI_getpid)
weak_alias (__getpid, __GI___getpid)
