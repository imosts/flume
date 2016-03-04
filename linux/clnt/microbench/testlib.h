#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

#define FLUSH_BLOCK_SIZE (65536)
#define BUFLEN 128

void init_test (char *progname, char *rodir, char*rwdir, int num_dirs, int flush_size_mb);
void start();
double stop();
void filename_exists (int readonly, char *buf, int buflen, int fileno);
void filename_noent (char *buf, int buflen, int fileno, int public);
void create_dirs ();
void clean_dirs ();
void create_flush_file ();
void flush_cache ();
long min (long a, long b);


