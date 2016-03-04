
#include "flume_api.h"
#include <stdlib.h>
#include <string.h>

/*
 * Global errno value for the flumeclnt (independent of the system's errno).
 */
static int _flume_errno;
static char *_flume_errstr;

int flume_get_flm_errno() { return _flume_errno; }
const char *flume_get_errstr() { return _flume_errstr; }

void flume_set_flm_errno(int n)
{
  _flume_errno = n;
}

void flume_set_errstr (const char *s)
{
#ifndef IN_RTLD
  if (_flume_errstr) {
    free (_flume_errstr);
  }
  if (s)
    _flume_errstr = strdup (s);
  else
    _flume_errstr = NULL;
#endif
}

void
flume_set_err (int c, const char *s)
{
  flume_set_flm_errno (c);
  flume_set_errstr (s);
}
