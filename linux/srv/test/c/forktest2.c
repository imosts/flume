
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include "sysflume.h"
#include "flumeclnt_c.h"
#include "libflumec.h"
#include <string.h>

int main (int argc, char *argv[]) {

  pid_t pid;
  int rc, fd;
  x_handle_tc fdh;
  char *s = "Test Message";
  
  rc = flume_socketpair (DUPLEX_THEM_TO_ME, &fd, &fdh);
  if (rc < 0) {
    fprintf (stderr, "could not create socketpair, err %d\n", flume_errno);
    exit (-1);
  }
  fprintf (stderr, "parent: socket fd is %d\n", fd);
  

  pid = flume_fork_safe();
  if (pid) {
    fprintf (stderr, "parent: my pid %d\n", getpid());

    char buf[1024];
    bzero (buf, 1024);

    fprintf (stderr, "parent: waiting for child to send\n");
    int rc = read (fd, buf, 1024);
    fprintf (stderr, "parent: got %d bytes, [%s]\n", rc, buf);

    fprintf (stderr, "parent: exiting\n");
    exit (0);

  } else {
    fprintf (stderr, "child: my pid %d\n", getpid());

    fd = flume_claim_socket (fdh);
    if (fd < 0) {
      fprintf (stderr, "error claiming socket fd, err %d\n", flume_errno);
      exit (-1);
    }
    rc = write (fd, s, strlen(s));
    fprintf (stderr, "child: sent %d bytes\n", rc);

    close (fd);
    exit (0);
  }

  return 0;
}
