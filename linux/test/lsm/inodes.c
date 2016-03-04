
/*
 * a little script to test out how different syscalls affect how
 * inodes are accessed
 */

#include <sys/prctl.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <fcntl.h>

#include "flume_const.h"

void
print_time(const char *s)
{
  time_t t = time (NULL);
  printf ("%lx: %s\n", t, s);
}

int
main (int argc, char *argv[])
{
#define BUFSZ 4096
  const char *file = "/tmp/lsm-inodes";
  int fd, rc;
  char buf[BUFSZ];
  size_t len;
  struct stat sb;

  print_time ("startup");

  if (prctl (FLUME_PRCTL_ENABLE, FLUME_CONFINE_VOLUNTARY, -1, 0, 0) < 0) {
    fprintf (stderr, "prctl failed: %s\n", strerror (errno));
    exit (1);
  }

  fd = open (file, O_CREAT | O_WRONLY, 0644);
  if (fd < 0) {
    fprintf (stderr, "creat ('%s') failed: %s\n", file, strerror (errno));
    exit (1);
  }

  rc = fstat (fd, &sb);
  if (fd < 0) {
    fprintf (stderr, "stat failed: %s\n", strerror (errno));
    exit (1);
  }

  printf ("Inode %s -> %llx,%lx\n", file, sb.st_dev, sb.st_ino);

  print_time ("open + sleep 5");
  sleep (5);
 
  print_time ("doing write....");
  len = snprintf (buf, BUFSZ, "foo foo bar bar\n");
  if (write (fd, buf, len) < 0) {
    fprintf (stderr, "write failed: %s\n", strerror (errno));
    exit (1);
  }

  print_time ("did write + sleep 5");
  sleep (5);
  print_time ("close file");
  close (fd);

  print_time ("did close + sleep 5");
  sleep (5);

  print_time ("doing open");
  fd = open (file, O_RDONLY);
  if (fd < 0) {
    fprintf (stderr, "open ('%s') failed: %s\n", file, strerror (errno));
    exit (1);
  }
  print_time ("did open + sleep 5");
  sleep (5);

  print_time ("doing read...");
  memset (buf, 0, BUFSZ);
  len = read (fd, buf, BUFSZ);
  if (len < 0) {
    fprintf (stderr, "read failed: %s\n", strerror (errno));
    exit (1);
  }
  print_time ("did read");

  printf ("read data: %s\n", buf);
  print_time ("did read + sleep 5");
  sleep (5);

  print_time ("doing close");
  close (fd);

#undef BUFSZ
  return 0;
}
