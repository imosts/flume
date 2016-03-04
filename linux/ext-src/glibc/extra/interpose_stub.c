
#include <elf.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <libintl.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ldsodefs.h>
#include <bits/wordsize.h>
#include <sys/mman.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/types.h>
#include "dynamic-link.h"
#include <stackinfo.h>
#include <caller.h>
#include <sysdep.h>

#include <dl-dst.h>

// note, to build this and link with the rest of ld.so, add to
// dl-routines elf/Makefile

// Note: This is a temporary stub binding for use when building glibc the  
// first time. The second time around, when we rebuild ld.so, we do
// something useful.

int __orig_open (const char *file, int oflag, ...)
{
  int mode = 0;
  if (oflag & O_CREAT) {
    va_list arg;
    va_start (arg, oflag);
    mode = va_arg (arg, int);
    va_end (arg);
  }
  return __open (file, oflag, mode);
}

int __orig_xstat64 (int v, const char *b, struct stat64 *st)
{
   return __xstat64 (v, b, st);
}

int __orig_access (const char *file, int mode)
{
  return __access (file, mode);
}

pid_t __orig_getpid (void)
{
  return __getpid ();
}

int 
__flume_ld_so_open (const char *file, int mode)
{
   if (file)
      _dl_debug_printf ("my ld so open! %s\n", file);
   return __orig_open (file, mode);
}

int 
__flume_ld_so_access (const char *file, int mode)
{
  if (file)
    _dl_debug_printf ("my ld so access! %s\n", file);
  return __orig_access (file, mode);
}

int 
__flume_ld_so_xstat64 (int v, const char *b, struct stat64 *st)
{
   return __orig_xstat64 (v, b, st);
}

pid_t
__flume_ld_so_getpid (void)
{
  return __orig_getpid ();
}

weak_alias (__flume_ld_so_open, flume_ld_so_open);
weak_alias (__flume_ld_so_xstat64, flume_ld_so_xstat64);
weak_alias (__flume_ld_so_access, flume_ld_so_access);
weak_alias (__flume_ld_so_getpid, flume_ld_so_getpid);

