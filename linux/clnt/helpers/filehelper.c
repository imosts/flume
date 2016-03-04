#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "flume_clnt.h"

#define BUFSIZE 8192
#define STDIN 0
#define STDOUT 1
#define STDERR 2

static char *prog_name;
static char buf[BUFSIZE];

void usage () {
  fprintf (stderr, "%s {read|write} path\n", prog_name);
  fprintf (stderr, "   for reads, returns data over stdout.\n");
  fprintf (stderr, "   for writes, reads data from stdin.\n");
  exit (1);
}

int copy (fd1, fd2) {
  int rc, rc2, remaining;

  // This could be more efficient but who cares..
  while ((rc = read (fd1, buf, BUFSIZE)) > 0) {
    remaining = rc;
    while (remaining > 0) {
      rc2 = write (fd2, buf, remaining);
      if (rc2 < 0)
        return -1;
      remaining -= rc2;
    }
  }
  if (rc)
    return -2;
  return 0;
}

int handle_read (char *path) {
  int fd;
  if ((fd = open (path, O_RDONLY)) < 0)
    return -3;
  return copy (fd, STDOUT);
}

int handle_write (char *path, x_labelset_t *ls) {
  int fd;
  if ((fd = flume_open (path, O_WRONLY | O_CREAT | O_TRUNC, 0644, ls, ls)) < 0) {
    return -4;
  }
  return copy (STDIN, fd);
}

int parse_thaw (const char *s, x_label_t *l) {
  x_handle_t h;
  if (handle_from_armor (s, &h))
    return -10;
  if (flume_thaw_label (l, &h))
    return -11;
  return 0;
}

int main (int argc, char *argv[]) {
  int rc = -1;
  prog_name = argv[0];

  /*
  fprintf (stderr, "reading %s\n", argv[2]);
  x_labelset_t *ls = labelset_alloc ();
  flume_get_labelset (ls);
  labelset_print (stderr, "filehelper proc", ls);
  */

  if (argc != 3 && argc != 6)
    usage ();

  if (!strcmp (argv[1], "read")) 
    rc = handle_read (argv[2]);
  else if (!strcmp (argv[1], "write")) {
    if (argc != 6)
      usage ();

    x_labelset_t *ls = labelset_alloc ();
    if ((rc = parse_thaw (argv[3], labelset_get_S (ls))))
      return rc;
    if (!rc && (rc = parse_thaw (argv[4], labelset_get_I (ls))))
      return rc;
    if (!rc && (rc = parse_thaw (argv[5], labelset_get_O (ls))))
      return rc;

    //labelset_print (stderr, "file ls", ls);
    if (!rc)
      rc = handle_write (argv[2], ls);
    
  } else
    usage ();

  if (rc)
    fprintf (stderr, "path %s rc %d errno %m\n", argv[2], rc);

  //fprintf (stderr, "helper %s exiting\n", argv[2]);
  return rc;
}
