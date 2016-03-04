

#ifndef _FLUME_LD_SO_INTERPOSE_H_
#define _FLUME_LD_SO_INTERPOSE_H_

#define __open(...) flume_ld_so_open(__VA_ARGS__)
#define __xstat64(...) flume_ld_so_xstat64(__VA_ARGS__)
#define __access(...) flume_ld_so_access(__VA_ARGS__)
#define __getpid(...) flume_ld_so_getpid (__VA_ARGS__)

int flume_ld_so_open (const char *file, int mode, ...);
int flume_ld_so_xstat64 (int v, const char *b, struct stat64 *st);
int flume_ld_so_access (const char *file, int mode);
int flume_ld_so_getpid (void);

#endif // _FLUME_LD_SO_INTERPOSE_H_

