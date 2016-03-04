#ifdef USE_FLUME
#include "flume_features.h" // must come before <sys/stat.h>
#endif

#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/wait.h>

#ifdef USE_FLUME
#include "flume_cpp.h"
#include "flume_prot.h"
#include "flume_api.h"
#include "flume_clnt.h"
#endif

#include "testlib.h"
#define __STDC_FORMAT_MACROS
#include <inttypes.h>

static char *prog_name;
static char buf[FLUSH_BLOCK_SIZE];
extern char **environ;

#define CHILD_FLAG "flume-child"
#define PINGPONG_MSGSIZE 1

#define dfprintf if (0) fprintf

void usage () {
  fprintf (stderr, "%s: {obsd} <mb> <nmsgs>\n", prog_name);
  fprintf (stderr, "%s: {flume} <mb> <nmsgs> <nullmsgs>\n", prog_name);
  fprintf (stderr, "  output format is: operation MB transferred, total_time, MB/sec\n");
  exit (1);
}

void report_lat (const char *s, int total, double elapsed) {
  printf("%-20s\t%d\t% 5.0lf\t% 5.3lf\n", s, total, elapsed*1000000, (elapsed/total) * 1000000);
}

void report_bw (const char *s, int mb, double elapsed) {
  printf("%-20s\t%d\t% 5.3lf\t% 5.3lf\n", s, mb, elapsed, (mb/elapsed));
}

void bw_send_bytes (int fd, unsigned long long sendbytes) {
  unsigned long long count=0;
  int n;

  memset (buf, 0xc5, FLUSH_BLOCK_SIZE);  

  while (count < sendbytes) {
    if ((n = write (fd, buf, FLUSH_BLOCK_SIZE)) <= 0) {
      fprintf (stderr, "sender: error sending\n");
      exit (1);
    }

    count += n;
    dfprintf (stderr, "sender: sent %d bytes, total %llu\n", n, count);
  }

  dfprintf (stderr, "sender: wrote %llu bytes, each\n", count);
  close (fd);
}

void bw_recv_bytes (int fd, unsigned long long bytes) {
  unsigned long count=0;
  int n, i=0;

  while ((n = read (fd, buf, FLUSH_BLOCK_SIZE)) > 0) {
    count += n;
    dfprintf (stderr, "receiver: read %d bytes, total %lu, i = %d\n", n, count, i++);
  }
  if (n < 0) {
    fprintf (stderr, "receiver: read error errno %d\n", errno);
    exit (1);
  }
  dfprintf (stderr, "receiver: done got %lu bytes\n", count);
}

void lat_send_msgs (int forw, int rev, int nmsgs) {
  memset (buf, 0xc5, FLUSH_BLOCK_SIZE);  
  int i, n;

  for (i=0; i<nmsgs; i++) {
    n = write (forw, buf, PINGPONG_MSGSIZE);
    if (n != PINGPONG_MSGSIZE) {
      fprintf (stderr, "lat_send_msgs: send %i err errno %d\n", i, errno);
      exit (1);
    }
    
    n = read (rev, buf, PINGPONG_MSGSIZE);
    if (n != PINGPONG_MSGSIZE) {
      fprintf (stderr, "lat_send_msgs: recv %i err errno %d\n", i, errno);
      exit (1);
    }
  }
}

void lat_recv_msgs (int forw, int rev, int nmsgs) {
  int i, n;

  for (i=0; i<nmsgs; i++) {
    n = read (forw, buf, PINGPONG_MSGSIZE);
    if (n != PINGPONG_MSGSIZE) {
      fprintf (stderr, "lat_recv_msgs: recv err errno %d\n", errno);
      exit (1);
    }

    n = write (rev, buf, PINGPONG_MSGSIZE);
    if (n != PINGPONG_MSGSIZE) {
      fprintf (stderr, "lat_recv_msgs: send err errno %d\n", errno);
      exit (1);
    }
  }
}

void bench_obsd (int mb, unsigned long long sendbytes, int nmsgs) {
  pid_t pid;
  int p[2], rc;

  
  if ((rc = socketpair (AF_LOCAL, SOCK_STREAM, 0, p) < 0)) {
    //if ((rc = pipe (p) < 0)) {

    fprintf (stderr, "pipe error errno %d\n", errno);
    exit (1);
  }

  if ((pid = fork()) < 0) {
    fprintf (stderr, "fork error errno %d\n", errno);
    exit (1);
  }

  if (pid) {
    close (p[0]);

    // Do latency test
    start ();
    lat_send_msgs (p[1], p[1], nmsgs);
    report_lat ("ipc_lat(us)", nmsgs, stop());

    // Do bw test
    start ();
    bw_send_bytes (p[1], sendbytes);
    wait (&rc);
    report_bw ("ipc_bw", mb, stop());

  } else {
    close (p[1]);

    // Do latency test
    lat_recv_msgs (p[0], p[0], nmsgs);

    // Do bw test
    bw_recv_bytes (p[0], sendbytes);
  }
}

#ifdef USE_FLUME
void bench_flume (int mb, unsigned long long sendbytes, int nmsgs, int nullmsgs) {
  x_handle_t pid;
  int forw, rev, rc;
  x_handle_t forwh, revh;
  const char *argv[6];
  const char *user = getenv ("USER");
  char buf0[BUFLEN];
  char buf1[BUFLEN];
  char buf2[BUFLEN];
  char buf3[BUFLEN];

  dfprintf (stderr, "flume_socketpair\n");

  if ((rc = flume_socketpair (DUPLEX_ME_TO_THEM, &forw, &forwh, "forward")) < 0) {
    fprintf (stderr, "flume_socketpair1 error errno %d\n", errno);
    exit (1);
  }

  if ((rc = flume_socketpair (DUPLEX_THEM_TO_ME, &rev, &revh, "reverse")) < 0) {
    fprintf (stderr, "flume_socketpair2 error errno %d\n", errno);
    exit (1);
  }

  snprintf (buf0, BUFLEN, "/disk/%s/run/bin/ipc-bench-flume", user);
  snprintf (buf1, BUFLEN, "0x%" PRIx64 , forwh);
  snprintf (buf2, BUFLEN, "0x%" PRIx64 , revh);
  snprintf (buf3, BUFLEN, "%d", nmsgs);

  argv[0] = buf0;
  argv[1] = CHILD_FLAG;
  argv[2] = buf1;
  argv[3] = buf2;
  argv[4] = buf3;
  argv[5] = NULL;

  rc = flume_spawn (&pid, argv[0], (char *const*) argv,
		    environ, 2, 0, 
		    NULL, NULL, NULL, NULL);
  if (rc < 0) {
    fprintf (stderr, "flume_spawn error errno %d\n", errno);
    exit (1);
  }

  start ();
  lat_send_msgs (forw, rev, nmsgs);
  report_lat ("ipc_lat(us)", nmsgs, stop());

  start ();
  dfprintf (stderr, "sending bytes\n");
  bw_send_bytes (forw, sendbytes);
  wait (&rc);
  report_bw ("ipc_bw", mb, stop());
}

void bench_flume_recv (char *forws, char *revs, int nmsg, unsigned long long sendbytes) {
  int forwfd, revfd;
  x_handle_t forwh, revh;

  if (handle_from_str (forws, &forwh) < 0) {
    fprintf (stderr, "handle_from_str err1\n");
    exit (1);
  }
  if (handle_from_str (revs, &revh) < 0) {
    fprintf (stderr, "handle_from_str err2\n");
    exit (1);
  }
  
  if ((forwfd = flume_claim_socket (forwh, "forward")) < 0) {
    fprintf (stderr, "claim_socket err1\n");
    exit (1);
  }

  if ((revfd = flume_claim_socket (revh, "reverse")) < 0) {
    fprintf (stderr, "claim_socket err2\n");
    exit (1);
  }

  lat_recv_msgs (forwfd, revfd, nmsg);
  bw_recv_bytes (forwfd, sendbytes);
}
#endif

int main (int argc, char *argv[]) {

  prog_name = argv[0];
  int mb, nmsgs;
  unsigned long long sendbytes = 0;

  if (argc < 3)
    usage ();

  if (argc >= 4) {
    mb = atoi (argv[2]);
    nmsgs = atoi (argv[3]);
    sendbytes = (unsigned long long)mb * 1024 * 1024;
  }
  
  if (!strcmp (argv[1], "obsd")) {
    if (argc != 4) 
      usage ();
    bench_obsd (mb, sendbytes, nmsgs);

#ifdef USE_FLUME
  } else if (!strcmp (argv[1], "flume")) {
    int nullmsgs;
    if (argc != 5) 
      usage ();
    nullmsgs = atoi (argv[4]);
    bench_flume (mb, sendbytes, nmsgs, nullmsgs);

  } else if (!strcmp (argv[1], CHILD_FLAG)) {
    if (argc != 5) {
      fprintf (stderr, "error with spanwed child arguments, "
               "expected <%s> <forw_handle> <rev_handle> <nmsgs>\n", CHILD_FLAG);
      exit (1);
    }
    nmsgs = atoi (argv[4]);
    bench_flume_recv (argv[2], argv[3], nmsgs, sendbytes);
#endif
  } else {
    usage ();
  }
  return 0;
}

#undef dfprintf
