#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>
#include <stdlib.h>
#include <time.h>
#include <errno.h>

#define SIZE	8192

static char buf[SIZE];
static char name[32] = "test_file";
static char *prog_name;
static int fd;


time_t ds;
time_t du;

struct timeval s;

void 
start()
{
    gettimeofday(&s, NULL);
}


double 
stop()
{
  time_t ds;
  time_t du;
  struct timeval f;
  gettimeofday(&f, NULL);
  ds = f.tv_sec - s.tv_sec;
  du = f.tv_usec - s.tv_usec;
  return (ds) + ((double)du/1000000.0);
}


#define TRULY_RANDOM

int fff(int i, int n)
{
    return ((i * 11) % n);
}

off_t 
random_offset(off_t max) {
#ifdef TRULY_RANDOM
  return (off_t)((double)rand()/RAND_MAX*max);
#else
  assert(0);
#endif
}
int write_test(int n, int size, int sequential)
{
    int i;
    int r;
    int fd;
    long pos;
    double elapsed;

    if (sequential) 
      printf(" writing %d sequential bytes: ", n*size);
    else
      printf(" writing %d random bytes: ", n*size);
    fflush(stdout);
    flush_cache();
    start();
    if((fd = open(name, O_RDWR)) < 0) {
	printf("%s: open %d failed %d %d\n", prog_name, i, fd, errno);
	exit(1);
    }

    for (i = 0; i < n; i ++) {
      if (!sequential) {
	
	pos = random_offset(n*size);
	if ((r = lseek(fd, pos, SEEK_SET)) < 0) {
	  printf("%s: lseek failed %d %d\n", prog_name, r, errno);
	}
      }
      
      if ((r = write(fd, buf, size)) < 0) {
	printf("%s: write failed %d %d (%ld)\n", prog_name, r, errno,
	       pos);
	exit(1);
      }
    }
    
    fsync(fd);

    if ((r = close(fd)) < 0) {
      printf("%s: close failed %d %d\n", r, errno);
    }

    elapsed = stop();
    printf("%d bytes in %f sec = %f KB/sec\n", n*size, elapsed, (n*size)/(1000*elapsed));

}


int g(int i, int n)
{
    if (i % 2 == 0) return(n / 2 + i / 2);
    else return(i / 2);
}


int read_test(int n, int size, int sequential)
{
    int i;
    int r;
    int fd;
    long pos;
    double elapsed;

    if (sequential) 
      printf(" reading %d sequential bytes: ", n*size);
    else
      printf(" reading %d random bytes: ", n*size);

    fflush(stdout);
    flush_cache ();
    start();
    if((fd = open(name, O_RDONLY)) < 0) {
      printf("%s: open %d failed %d %d\n", prog_name, i, fd, errno);
      exit(1);
    }
    
    for (i = 0; i < n; i ++) {
      if (!sequential) {
	
	pos = random_offset(n * size);
	if ((r = lseek(fd, pos, 0)) < 0) {
	  printf("%s: lseek failed %d %d\n", prog_name, r, errno);
	}
      }
      
      if ((r = read(fd, buf, size)) < 0) {
	printf("%s: read failed %d %d\n", prog_name, r, errno);
	exit(1);
      }
    }
    
    if ((r = close(fd)) < 0) {
      printf("%s: close failed %d %d\n", r, errno);
    }
    

    elapsed = stop();
    printf("%d bytes in %f sec = %f KB/sec\n", n*size, elapsed, (n*size)/(1000*elapsed));
}


int flush_cache()
{
    int i, r;

    if((fd = open("t", O_RDWR | O_CREAT | O_TRUNC, S_IRWXU)) < 0) {
	printf("%s: create %d failed %d %d\n", prog_name, i, fd, errno);
	exit(1);
    }

    for (i = 0; i < 150000; i ++) {
	if ((r = write(fd, buf, 4096)) < 0) {
	    printf("%s: write failed %d %d (%ld)\n", prog_name, r, errno);
	    exit(1);
	}
    }
    
    fsync(fd);

    if ((r = close(fd)) < 0) {
	printf("%s: mnx_close failed %d %d\n", r, errno);
    }

    unlink("t");
}



int main(int argc, char *argv[])
{
    int n;
    int size;
    int totalsize;

    prog_name = argv[0];

    if (argc != 2) {
	printf("%s usage: %s size (in MB)\n", prog_name, prog_name);
	exit(1);
    }

    srand(time(NULL));
    totalsize = atoi(argv[1])*1024*1024;
    if (totalsize > 1024*1024*256) {
      totalsize = 1024*1024*256;
      fprintf(stderr, "capping file size at 256MB\n");
    }
    size = 4096;
    n = totalsize/size;

    printf("large file benchmark: %d %d-byte writes\n", n, size);

    srandom(getpid());

    if((fd = creat(name, S_IRUSR | S_IWUSR)) < 0) {
	printf("%s: create %d failed %d\n", prog_name, fd, errno);
	exit(1);
    }

    write_test(n, size, 1);
    read_test(n, size, 1);
    write_test(n , size, 0);
    read_test(n, size, 0);
    //read_test(n , size, 1);

    unlink(name);

    sync();
}

