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
  printf ("<h2>simplecgi</h2>\n");
  printf ("<form action=/cgi-bin/cgilaunch method=get>\n"
          "<input type=hidden name=UN value='%s'>\n"
          "<input type=hidden name=PW value='%s'>\n"
          "<input type=hidden name=EXEC value='%s'>\n"
          "<b>Read file:</b> &nbsp;\n"
          "<input name=FILE type=text> &nbsp;\n"
          "<input type=submit name=submit value=submit>\n"
          "</form>\n", 
          cgl_getvalue("UN"), cgl_getvalue("PW"),cgl_getvalue("EXEC"));
}

int
main (int argc, char *argv[])
{
  int handle;
  int rc=0;
  char buffer[256];
  char *file;

  if (cgl_init() < 0) {
    fprintf (stderr, "cgl_init() error %d\n", rc);
    return -1;
  }
  
  cgl_html_header ();
  cgl_html_begin ("simplecgi!");

  if (!(file = cgl_getvalue("FILE"))) {
    output_form ();
    goto done;
  }

  printf ("<h2>simplecgi: file %s</h2>\n", file);

  if ((handle = open(file, O_RDONLY)) < 0) {
    printf ("Error reading file %s\n", file);
    goto done;
  }

  rc = read(handle, buffer, 256);
  if (rc > 0) {
    buffer[rc]='\0';
    printf("file starts with %s\n", buffer);
  } else if (rc == 0) {
    printf("file is empty\n");
  } else {
    printf("error reading file: %d\n", rc);
  }
  close(handle);

 done:
  cgl_html_end();
  cgl_freeall();
  return 0;
} 
