#include <sys/time.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <errno.h>

#define TIMING_BUF_MB 1
#define TIMING_BUF_BYTES TIMING_BUF_MB * 1024 * 1024
#define LAT_TEST_BYTES 512

struct itimerval e1;

void time_device(long test_size, char *devname);
int read_chunk (int fd, void *buf);
void test_latency (long num_reads, char *devname);

int
main(int argc, char **argv) {
  
  if (argc != 4) {
    printf("usage: %s -bl <device> <test size>\n\n"
	   "Measuring disk read throughput: -b"
	   "examples (Linux-SCSI): -b /dev/sda 64\n"
	   "         (Linux-IDE): -b /dev/hda 64\n"
	   "         (OpenBSD-SCSI)  -b /dev/rsd0c 64\n"
	   "         (OpenBSD-IDE): -b /dev/rwd0c 64\n"
	   "         (FreeBSD-SCSI): -b /dev/rda0 64\n"
	   "\n\nMeasuring block read atency: -l"
	   "         (Linux-SCSI): -l /dev/sda 1000\n "
	   "         (others by example from above)\n",
	   argv[0]);
    exit(0);
  }

  srand(time(NULL));
  char *devname = argv[2];
  int testsize = atoi(argv[3]);
  
  if (strcmp(argv[1], "-b") == 0)
    time_device(testsize, devname);
  else
    test_latency(testsize, devname);

}

/* stolen from hdparm-4.1: http://www.ibiblio.org/pub/Linux/system/hardware/ */
/* read_chunk reads 1MB (TIMING_BUF_BYTES) off the disk */
int 
read_chunk (int fd, void *buf)
{
  int i, rc;
  if ((rc = read(fd, buf, TIMING_BUF_BYTES)) != TIMING_BUF_BYTES) {
    if (rc)
      perror("read() failed");
    else
      fputs ("read() hit EOF - device too small\n", stderr);
    return 1;
  }
  /* access all sectors of buf to ensure the read fully completed */
  for (i = 0; i < TIMING_BUF_BYTES; i += 512)
    ((char *)buf)[i] &= 1;
  return 0;
}

void
reset_timer () 
{
  struct itimerval in;
  in.it_interval.tv_sec = 600;
  in.it_interval.tv_usec = 0;
  in.it_value.tv_sec = 600;
  in.it_value.tv_usec = 0;
  setitimer(ITIMER_REAL, &in, NULL);
}

inline void
start_timer () 
{
  getitimer(ITIMER_REAL, &e1);
}

inline double 
timer_elapsed () 
{
  struct itimerval e2;
  getitimer(ITIMER_REAL, &e2);

  double elapsed = (e1.it_value.tv_sec - e2.it_value.tv_sec)
    + ((double)(e1.it_value.tv_usec - e2.it_value.tv_usec) / 1000000.0);

  return elapsed;
}

off_t 
random_offset(off_t max) {
  return (off_t)((double)rand()/RAND_MAX*max);
}

void
test_latency (long num_reads, char *devname) 
{
  
  int fd = open (devname, O_RDONLY);
  if (fd < 0) {
    printf("could not open %s\n", devname);
    return;
  }
  
  void *buf = malloc(LAT_TEST_BYTES);

  reset_timer();


  /*
    Buffer cache read is < 1 usec on 1Ghz CPU.
    don't bother correcting for this.

    printf(" Timing %d reads from the buffer cache: ", num_reads);
    fflush(stdout);

  //time some reads from the buffer cache
  // we'll subtract this time out later
  lseek (fd, 0, SEEK_SET);
  int err = read(fd, buf, LAT_TEST_BYTES); //get it in the cache
  double correction_lat = 0.0;
  for (int i = 0; i < num_reads; i++) {
    start_timer();
    err = read(fd, buf, LAT_TEST_BYTES);
    lseek (fd, 0, SEEK_SET);
    correction_lat += timer_elapsed();
  }
  printf ("%d reads in %f sec = %f usec\n",
	  num_reads,
	  correction_lat,
	  1000000*correction_lat/num_reads);

  */

  printf(" Timing %d reads on %s: ", num_reads, devname);
  fflush(stdout);  
  double total_latency = 0.0;
  for (int i = 0; i < num_reads; i++) {
    off_t rpos = random_offset(1024*1024*1000);
    off_t pos = lseek(fd, rpos, SEEK_SET);
    if (pos < 0) {
      fprintf (stderr, "error seeking to %dth byte;"  
	       "partition used to test latency must be > 1GB\n", rpos);
      exit (-1);
    }
    start_timer();
    int err = read(fd, buf, LAT_TEST_BYTES);
    total_latency += timer_elapsed();
    if (err != LAT_TEST_BYTES) {
      if (err == 0) printf("out of space on %s at %u\n", devname, rpos);
      else perror("Measuring latency");
      goto bail;
    }
  }

  printf(" %d reads in %f secs = %f msec average latency\n", num_reads, total_latency, 1000*total_latency/num_reads);
  
 bail:
  free(buf);
  close(fd);
	 
}
/* stolen from hdparm-4.1: http://www.ibiblio.org/pub/Linux/system/hardware/ */
/* Got rid of the shared segment for memory --FED */
void 
time_device (long test_size, char *devname)
{
  
  int fd = open (devname, O_RDONLY);
  if (fd < 0) {
    printf("could not open %s\n", devname);
    return;
  }

  void *buf = malloc(TIMING_BUF_BYTES);
  if (NULL == buf) { 
    printf ("count not allocate %d bytes of memory", TIMING_BUF_BYTES);
    exit(-1);
  }

  
  printf(" Timing device %s:  ", devname);
  fflush(stdout);
  
  reset_timer();
  
  /* Now do the timings */
  struct itimerval e1, e2;
  int count = test_size / TIMING_BUF_MB + 1;
  
  start_timer();
  for (int i = count; i > 0; --i) 
    {
      if (read_chunk (fd, buf)) {
	free(buf);
	close(fd);
      }
    }

  double elapsed = timer_elapsed();

  int countmb = count*TIMING_BUF_MB;
  printf("%2d MB in %5.2f seconds =%6.2f MB/sec\n",
	 countmb, elapsed, countmb / elapsed);
  
  free (buf);
  close(fd);
  return;

}



