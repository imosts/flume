
#ifndef _FLUME_DEBUG_H_
#define _FLUME_DEBUG_H_

int flume_do_debug (int l);

#ifdef IN_RTLD

//
// In an ideal world, we can pull this definition in from glibc source;
// however, need to do a lot of work to get that operational. Do this
// easy thing for the time being.
//
extern void _dl_dprintf (int fd, const char *fmt, ...)
     __attribute__ ((__format__ (__printf__, 2, 3)));

# define FLUME_WARN_PRINTF(fmt, ...) \
   _dl_dprintf (STDERR_FILENO, "flume: " fmt, ##__VA_ARGS__)
# define FLUME_ERROR_PRINTF(fmt, ...) \
   _dl_dprintf (STDERR_FILENO, "flume: " fmt, ##__VA_ARGS__)

#else 
# define FLUME_WARN_PRINTF(...) fprintf(stderr, __VA_ARGS__)
# define FLUME_ERROR_PRINTF(...) fprintf(stderr, __VA_ARGS__)
#endif

#define FLUME_DEBUG(l, f, fmt, ...) \
  do { \
    if (flume_do_debug (l)) { FLUME_WARN_PRINTF (fmt, ##__VA_ARGS__); } \
  } while (0)

#define FLUME_DEBUG2(l, fmt, ...) \
  do { \
    if (flume_do_debug (l)) { FLUME_WARN_PRINTF (fmt, ##__VA_ARGS__); } \
  } while (0)

#endif /* _FLUME_DEBUG_H_ */
