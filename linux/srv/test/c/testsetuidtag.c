
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

int
main (int argc, char *argv[])
{
  x_handle_tc tag;
  int rc = flume_setuid_tag (&tag);
  if (rc < 0) {
    fprintf (stderr, "problem: %d\n", flume_errno);
  } else {
    printf ("Result: 0x%llx\n", tag);
  }
  return 0;
}
