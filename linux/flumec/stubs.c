
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

#include "flume_debug.h"

char *
flume_strdup (char *s)
{
#ifdef IN_RTLD
  size_t sz = strlen (s) + 1;
  char *ret = malloc (sz);
  memcpy (ret, s, sz);
#else /* ! IN_RTLD */
  char *ret = strdup (s);
#endif /* IN_RTLD */
  return ret;
}

void
flume_set_errno (int i)
{
#ifdef IN_RTLD
  extern int rtld_errno;
  rtld_errno = i;
#else /* ! IN_RTLD */
  errno = i;
#endif /* IN_RTLD */
}

#ifdef IN_RTLD

static long
strtol_jos (const char *s, char **endptr, int base)
{
  int neg = 0;
  long val = 0;

  // gobble initial whitespace
  while (*s == ' ' || *s == '\t')
    s++;
  
  // plus/minus sign
  if (*s == '+')
    s++;
  else if (*s == '-')
    s++, neg = 1;
  
  // hex or octal base prefix
  if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
    s += 2, base = 16;
  else if (base == 0 && s[0] == '0')
    s++, base = 8;
  else if (base == 0)
    base = 10;
  
  // digits
  while (1) {
    int dig;
    
    if (*s >= '0' && *s <= '9')
      dig = *s - '0';
    else if (*s >= 'a' && *s <= 'z')
      dig = *s - 'a' + 10;
    else if (*s >= 'A' && *s <= 'Z')
      dig = *s - 'A' + 10;
    else
      break;
    if (dig >= base)
      break;
    s++, val = (val * base) + dig;
    // we don't properly detect overflow!
  }
  
  if (endptr)
    *endptr = (char *) s;
  return (neg ? -val : val);
}


static unsigned long
fake_strtoul (const char *in, int *ok)
{
  char *ep;
  long lval = 0;
  int base = 0;

  if (!in || !*in) {
    *ok = 0;
    return 0;
  }

  lval = strtol_jos (in, &ep, base);
  if (*ep != 0 || lval < 0) 
    *ok = 0;
  else {
    *ok = 1;
  }

  return lval;
}
#endif

#ifndef IN_RTLD
static unsigned long
real_strtoul (const char *in, int *ok)
{
  char *ep;
  unsigned long lval;
  
  errno = 0;
  lval = strtoul (in, &ep, 0);

  if (in[0] == 0 || *ep != 0) {
    *ok = 0;
  } else if (lval >= INT_MAX) {
    *ok = 0;
  } else if (errno == ERANGE && lval == ULONG_MAX) {
    *ok = 0;
  } else {
    *ok = 1;
  }

  return lval;
}
#endif

unsigned long
flume_strtoul (const char *in, int *ok)
{

#ifdef IN_RTLD
  return fake_strtoul (in, ok);
#else
  return real_strtoul (in, ok);
#endif

}



