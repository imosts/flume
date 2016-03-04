#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include "cgl.h"

/**
 * Reads a local file and outputs to stdout
 */

void
output_form ()
{
  printf ("<h2>nullcgi</h2>\n");
}

int
main (int argc, char *argv[])
{
  int rc=0;

  if ((rc = cgl_init()) < 0) {
    fprintf (stderr, "cgl_init() error %d\n", rc);
    return -1;
  }
  
  cgl_html_header ();
  cgl_html_begin ("nullcgi!");
  output_form ();
  cgl_html_end();
  cgl_freeall();
  return 0;
} 
