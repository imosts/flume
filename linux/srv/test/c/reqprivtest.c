#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include "sysflume.h"
#include "flumeclnt_c.h"
#include "libflumec.h"
#include <stdio.h>
#include <stdlib.h>

int main (int argc, char *argv[]) {
  flume_status_tc status;
  x_handle_tc h, t;
  char *token;

  /* Create a new handle */
  status = flume_new_handle (&h, HANDLE_OPT_DEFAULT_ADD | HANDLE_OPT_PERSISTENT,
                        "testhandle");
  if (status) {
    printf ("error creating new handle\n");
    exit (1);
  }
  printf ("new handle is %llx\n", h);

  t = handle_construct (HANDLE_OPT_PERSISTENT |
                        CAPABILITY_SUBTRACT |
                        HANDLE_OPT_DEFAULT_ADD, h);
  status = flume_make_login (t, 0, 0, &token);
  printf ("random token is: %s\n", token);
  if (status) {
    printf ("error making login\n");
    exit (1);
  }

  printf ("Stage 1 O label: ");
  x_label_tc *lab = label_alloc (0);
  flume_get_label (lab, LABEL_O);
  label_print (stdout, lab);
  label_free (lab);
  fprintf (stderr, "\n");

  /* Get rid of our capability */
  status = flume_shrink_label (LABEL_O, h);
  printf ("shrink_label: return code %d\n", status);

  printf ("Stage 2 O label: ");
  lab = label_alloc (0);
  flume_get_label (lab, LABEL_O);
  label_print (stdout, lab);
  label_free (lab);
  fprintf (stderr, "\n");

  status = flume_req_privs (t, token);
  printf ("Stage 4 O label: ");
  lab = label_alloc (0);
  flume_get_label (lab, LABEL_O);
  label_print (stdout, lab);
  label_free (lab);
  fprintf (stderr, "\n");

  t = handle_construct (HANDLE_OPT_PERSISTENT | HANDLE_OPT_DEFAULT_ADD, handle_base (h));
  status = flume_expand_label (LABEL_S, t);
  printf ("expand_label: return code %d\n", status);
  printf ("Stage 4 S label: ");
  lab = label_alloc (0);
  flume_get_label (lab, LABEL_S);
  label_print (stdout, lab);
  label_free (lab);
  fprintf (stderr, "\n");

  return 0;
}
