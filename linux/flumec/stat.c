
#define _LARGEFILE_SOURCE 1
#define _LARGEFILE64_SOURCE 1
#include <sys/stat.h>

int 
flume_xstat64 (int vers, const char *file, struct stat64 *buf)
{
  return -1;
}

int 
flume_lxstat64 (int vers, const char *file, struct stat64 *buf)
{
  return -1;
}

int 
flume_xstat (int vers, const char *file, struct stat *buf)
{
  return -1;
}

int 
flume_lxstat (int vers, const char *file, struct stat *buf)
{
  return -1;
}
