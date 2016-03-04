
#include <stdlib.h>
#include <limits.h>
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/time.h>
#include "config.h"
#include "flume_prot_c.h"
#include "sysflume.h"
#include <errno.h>
#include <assert.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <unistd.h>
#include "flumeclnt_c.h"



int
main (int argc, char *argv[])
{
  int rc = 0;
#define BUFSZ 1024
  char buf[BUFSZ];
  pid_t pid;
  x_handle_tc tok;
  int pfd;
  int d;

  if (flume_socketpair (DUPLEX_THEM_TO_ME, &pfd, &tok) < 0) {
    fprintf (stderr, "socketpair failed\n");
    exit (-1);
  }
  pid = fork ();
  if (pid > 0) {
    while ((rc = read (pfd, buf, BUFSZ)) > 0) {
      printf ("%s", buf);
    }
    close (pfd);
    wait (&d);
  } else if (pid == 0) {
    pfd = flume_claim_socket (tok);
    if (pfd < 0) {
      fprintf (stderr, "error claiming fd\n");
    } else {
      close (0);
      close (2);
      close (1);
      dup2 (pfd, 1);
      printf ("now what\n");
      printf ("laa-tee-daa...\n");
      fflush (stdout);
      close (1);
      close (pfd);
      exit (0);
    }
  }
  return 0;
}
