
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

#include "flumeclnt_c.h"

extern char **environ;

int
main (int argc, char *argv[])
{
  const char *socket = "/tmp/flume-sock.mk";
  const char *file;
  char buf[16];
  int rc;
  int fd;
  x_handle_tc h;
  char *v[] = { "/usr/local/bin/python", 
		"/disk/max/run/pybin/printo.py", 
		NULL };

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

  rc = flume_spawn (&h, v[0], v, environ, 3, 0, NULL, NULL, NULL);
  if (rc < 0) {
    fprintf (stderr, "flume spawn failed with rc=%d\n", rc);
    exit (1);
  }
  fprintf (stderr, "Result => %llx\n", h);
  return 0;
}
