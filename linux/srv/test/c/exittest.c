

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
  x_label_tc l;
  label_init (&l);
  flume_get_label (&l, LABEL_O);
  return 0;
}
