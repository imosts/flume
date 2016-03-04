#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/time.h>
#include <time.h>
#include <string.h>
#include <assert.h>
#include "testlib.h"

static char _dir[BUFLEN];
static char _flush_file[BUFLEN];

static char *_rodir;
static char *_rwdir;
static char *_prog_name;

static long _flush_blocks;
static int _num_dirs;

static struct timeval s;
static int running = 0;

#define dprintf if (0) printf

void init_test (char *progname, char *rodir, char*rwdir, int num_dirs, int flush_size_mb) {
  _prog_name = progname;
  _rodir = rodir;
  _rwdir = rwdir;
  _num_dirs = num_dirs;
  _flush_blocks = (flush_size_mb * 1024 * 1024) / FLUSH_BLOCK_SIZE;
  snprintf (_flush_file, BUFLEN, "%s/FLUSH_FILE", _rwdir);
}

void start() {
  assert (!running);
  gettimeofday(&s, NULL);
  dprintf ("start %lu.%06lu\n", s.tv_sec, s.tv_usec);
  running = 1;
}

double stop() {
  long ds, du;

  struct timeval f;
  gettimeofday(&f, NULL);

  ds = f.tv_sec - s.tv_sec;
  du = f.tv_usec - s.tv_usec;
  dprintf ("stop  %lu.%06lu\n", f.tv_sec, f.tv_usec);
  running = 0;
  return ((double)ds) + ((double)du/(double)1000000.0);
}

void filename_exists (int readonly, char *buf, int buflen, int fileno) {
  int dirno = fileno % _num_dirs;
  char *dir = readonly ? _rodir : _rwdir;
  
  snprintf (buf, buflen, "%s/d%d/g%d", dir, dirno, fileno);
}

void filename_noent (char *buf, int buflen, int fileno, int public) {
  int dirno = fileno % _num_dirs;
  char *dir = public ? _rodir : _rwdir;

  snprintf (buf, buflen, "%s/d%d/xxx%d", dir, dirno, fileno);
}

void create_dirs () {
    int i;
    umask(0);

    if ((mkdir (_rwdir, 0777) < 0) && errno != EEXIST) {
      printf ("failure to mkdir %s, errno %d\n", _rwdir, errno);
      exit (1);
    }

    for (i = 0; i < _num_dirs; i++) {
        snprintf(_dir, BUFLEN, "%s/d%d", _rwdir, i);
        if (mkdir(_dir, 0777) < 0) {
          printf ("failure to mkdir %s, errno %d\n", _dir, errno);
          exit (1);
        }
    }
}

void clean_dirs() {
    int i;

    umask(0);
    for (i = 0; i < _num_dirs; i++) {
        snprintf(_dir, BUFLEN, "%s/d%d", _rwdir, i);
        rmdir(_dir);
    }
}

void create_flush_file () {
  int fd, r;
  long n;
  char buf[FLUSH_BLOCK_SIZE];
  struct stat sb;

  if (_flush_blocks == 0) 
    return;

  if (!stat (_flush_file, &sb)) {
    if (sb.st_size == FLUSH_BLOCK_SIZE * _flush_blocks) {
      printf ("using existing file to flush the cache (%lu bytes)\n", sb.st_size);
      fflush (stdout);
      return;
    } else {
      unlink (_flush_file);
    }
  }

  printf ("creating a temporary file used to flush the cache (%lu bytes): ", 
          FLUSH_BLOCK_SIZE * _flush_blocks);
  fflush (stdout);
  
  if((fd = open(_flush_file, O_WRONLY | O_CREAT/* | O_TRUNC*/, /*S_IRWXU*/ 0644)) < 0) {
    printf("%s: 1 failed to create temporary file used to flush the cache. "
	   "Make sure you have 1G free in this file system\n", 
	   _prog_name);
    exit(1);
  }
  
  memset (buf, 0xc5, FLUSH_BLOCK_SIZE);  
  for (n = 0; n < _flush_blocks; n++) {
    if ((r = write(fd, buf, FLUSH_BLOCK_SIZE)) < 0) {
      printf("%s: 2 failed to create temporary file used to flush the cache. "
	     "Make sure you have 1G free in this file system (%s)\n", 
	     _prog_name,
	     strerror (errno));
      unlink (_flush_file);
      exit(1);
    }
  }

  printf ("done.\n");
  close (fd);
}

void flush_cache()
{
  int fd, r;
  long n;
  char buf[FLUSH_BLOCK_SIZE];

  if (_flush_blocks == 0) 
    return;

  if((fd = open(_flush_file, O_RDONLY)) < 0) {
    printf("%s: failed to open %s\n", _prog_name, _flush_file);
    exit(1);
  }
  
  for (n = 0; n < _flush_blocks; n++) {
    if ((r = read(fd, buf, FLUSH_BLOCK_SIZE)) < 0) {
      printf("%s: failed to read %s\n", _prog_name, _flush_file);
      exit(1);
    }
  }
  close (fd);
}

long min (long a, long b) {
  return (a < b) ? a : b;
}

#undef dprintf
