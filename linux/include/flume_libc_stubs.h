
#ifndef _FLUME_LIBC_STUBS_H_
#define _FLUME_LIBC_STUBS_H_

/*
 * Some symbols have different behavior based on rtld-libc location
 * versus regular:
 */

char *flume_strdup (const char *s);
void flume_set_errno (int i);
unsigned long flume_strtoul (const char *in, int *ok);


#ifdef IN_RTLD

# define FLUME_PRId "%s%lu"
# define FLUME_PRId_ARG(x) \
  ((x) < 0 ? "-" : ""), (unsigned long)(((x) < 0) ? 0 - (x) : (x))

#else /* ! IN_RTLD */

# define FLUME_PRId "%d"
# define FLUME_PRId_ARG(x) x

#endif /* IN_RTLD */

#endif /* _FLUME_LIBC_STUBS_H_ */
