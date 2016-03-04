/*
 * Run in OpenBSD: 
 *   smallfb /disk/yipal/tmp/obsd 1024 100 1000 1024
 *
 * Run in Flume:
 *   LD_LIBRARY_PATH=/usr/local/lib:/disk/yipal/run/lib/flume/shared/runtime FLUME_DESIRED_RING=2 smallfb /disk/yipal/tmp/flume 1024 100 1000 1024
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>
#include <errno.h>
#include "testlib.h"

#define BIGBUF 40960
static char buf[BIGBUF];
static char name[BUFLEN];
static char *prog_name;
static char *tmpdir;
static int num_dirs;

void
creat_test(int n, int size)
{
    int i;
    int r;
    int fd;
    int j;
    double elapsed;

    start();
    for (i = 0, j = 0; i < n; i ++) {

      j = i % num_dirs;
      snprintf(name, BUFLEN, "%s/d%d/g%d", tmpdir, j, i);

      if((fd = open(name, O_WRONLY | O_CREAT/* | O_TRUNC*/, /*S_IRWXU*/ 0644)) < 0) {
	printf("%s: create %d(%s) failed %d %d\n", prog_name, i, name,
	       fd, errno);
	exit(1);
      }

      if (size > BIGBUF) {
	printf("%s: file size too big %d\n", prog_name, size);
	exit(1);
      }

      if ((r = write(fd, buf, size)) < 0) {
	printf("%s: write failed %d %d\n", prog_name, r, errno);
	exit(1);
      }
      
      if ((r = fsync (fd) < 0)) {
	printf ("%s: fsync failed: %s\n", strerror (errno));
      }

      if ((r = close(fd)) < 0) {
	printf("%s: close failed %d %d\n", r, errno);
      }
      
    }
    elapsed = stop();
    printf("creat: %d %d-byte files in  %lf sec = %f KB/sec\n",  
           n, size, elapsed, (n*size)/(1000*elapsed));
}

int read_test(int n, int size)
{
    int i;
    int r;
    int fd;
    int j;
    double elapsed;

    start();
    for (i = 0, j = 0; i < n; i ++) {
      
      j = i % num_dirs;
      snprintf(name, BUFLEN, "%s/d%d/g%d", tmpdir, j, i);
      
      if((fd = open(name, O_RDONLY)) < 0) {
	printf("%s: open %d failed %d %d\n", prog_name, i, fd, errno);
	exit(1);
      }
      
      if ((r = read(fd, buf, size)) < 0) {
	printf("%s: read failed %d %d\n", prog_name, r, errno);
	exit(1);
      }
      
      if ((r = close(fd)) < 0) {
	printf("%s: close failed %d %d\n", r, errno);
      }
      
    }
    elapsed = stop();
    
    printf("read: %d %d-byte files in %lf sec = %f KB/sec\n",  
	   n, size, elapsed, (n*size)/(1000*elapsed));
}

int delete_test(int n)
{	
    int i;
    int r;
    int fd;
    int j;
    double elapsed;

    start();
    for (i = 0, j = 0; i < n; i ++) {
      
      j = i % num_dirs;
      snprintf(name, BUFLEN, "%s/d%d/g%d", tmpdir, j, i);
      
      if ((r = unlink(name)) < 0) {
	printf("%s: unlink failed %d\n", prog_name, r);
	exit(1);
      }
      
    }

    elapsed = stop();
    printf("delete: %d files in %lf sec = %f files/sec\n",  n, elapsed,  n/elapsed);
}


int main(int argc, char *argv[])
{
  int num_files;
    int size;
    int flush_mb;

    prog_name = argv[0];

    if (argc != 6) {
	printf("%s: <tmpdir> <flushsizeMB> <num_dirs> <num_files> "
               "<file_size (in bytes)>\n", prog_name);
	exit(1);
    }

    tmpdir = argv[1];
    flush_mb = atoi (argv[2]);
    num_dirs = atoi (argv[3]);
    num_files = atoi (argv[4]);
    size = atoi (argv[5]);

    printf("small file benchmark: %d %d-byte files\n", num_files, size);

    init_test (prog_name, tmpdir, num_dirs, flush_mb);

    create_dirs ();
    create_flush_file ();

    creat_test (num_files, size);
    flush_cache ();

    read_test (num_files, size);
    flush_cache ();

    delete_test (num_files);
    clean_dirs ();
}


