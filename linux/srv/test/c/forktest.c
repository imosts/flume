
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include "sysflume.h"
#include "flumeclnt_c.h"
#include "libflumec.h"
#include <string.h>


int main (int argc, char *argv[]) {

  pid_t pid = flume_fork_safe();
  if (pid) {
    fprintf (stderr, "parent: my pid %d\n", getpid());

  } else {
    fprintf (stderr, "child: my pid %d\n", getpid());

    /* creat the file before tainting ourselves! */
    x_handle_tc h = 0x10000000000000f2LL;
    x_labelset_tc ls;
    memset ((void *)&ls, 0, sizeof (ls));
    ls.S.len = 1;
    ls.S.val = &h;
    
    int fd = flume_open ("/home/output", O_CREAT | O_WRONLY | O_TRUNC, 0644,
			&ls);
    close(fd);

    /* close the fd, and prove to the RM that we're safe */
    flume_check_safe ();
    
    /** The following line requests a secrecy handle that we do not own
     *  it would fail if we had not called flume_fork_safe()
     */
    flume_status_tc r = flume_expand_label (LABEL_S, 0x10000000000000f2LL);

    fprintf (stderr, "expand_label: return code %d\n", r);
    x_label_tc *lab = label_alloc (0);
    flume_get_label (lab, LABEL_S);
    label_print (stderr, lab);
    label_free (lab);
    fprintf (stderr, "\n");

    /* Read some secret data */
    const char *file = "/home/yipal4";
    int rc;
    if ((rc = open(file, O_RDONLY)) < 0)
      return 0;
    


    /* output secret data to a tainted file */
    fd = flume_open ("/home/output", O_WRONLY | O_TRUNC, 0644, &ls);
    FILE *f = fdopen (fd, "w");
    fprintf (f, "I know a secret!\n");
    fclose (f);

    close(fd);
  }

  return 0;
}
