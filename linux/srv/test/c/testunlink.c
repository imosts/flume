
#include <string.h>
#include <sys/types.h>
#include "sysflume.h"
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

int
main (int argc, char *argv[])
{
  const char *socket = "/tmp/flume-sock.mk";
  const char *file;
  char buf[16];
  int rc;
  int fd;

  if (argc != 2) {
    fprintf (stderr, "usage: %s <name>\n", argv[0]);
    exit (1);
  }
  file = argv[1];

  fd = unixsocket_connect_c (socket);
  if (fd < 0) {
    fprintf (stderr, "cannot connect to socket %s: %d\n", socket, errno);
    exit (1);
  }

  sprintf (buf, "%d", fd);
  setenv ("FLUME_CTL_SOCKET", buf, 1);

  rc = flume_open (file, 0, 0, NULL);
  if (rc < 0) {
    fprintf (stderr, "flume unlink failed with rc=%d\n", rc);
    exit (1);
  }
  return 0;
}
