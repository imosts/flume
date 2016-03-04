#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include "cgl.h"
#include "flumeclnt_c.h"
#include <errno.h>

/**
 * Attempts to fork and do some stuff that it cannot reveal to the web
 * client.
 */

int
run_parent ()
{
  if (cgl_init() < 0) {
    fprintf (stderr, "cgl_init() error %d\n", errno);
    return -1;
  }
    
  cgl_html_header ();
  cgl_html_begin ("forkcgi!");

  printf ("<h2>forkcgi</h2>\n");
    
  cgl_html_end();
  cgl_freeall();
  return 0;
}

int
run_child ()
{
  return 0;
}

int
main (int argc, char *argv[])
{
  pid_t pid = flume_fork_safe();
  if (pid)
    return run_parent();
  else
    return run_child();
} 
