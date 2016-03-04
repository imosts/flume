
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

static const char *progname;

static void
usage ()
{
  fprintf (stderr, 
	   "usage: %s\n"
	   "   Use this tool to restore your ld.so if an install of Flume "
	   "went bad.\n", progname);
  exit (0);
	   
}

static int
my_copy (const char *from, const char *to, uid_t uid, gid_t gid, mode_t mode)
{
#define BUFSZ 4096
  char buf[BUFSZ];
  ssize_t rc = -1;
  int fromfd = open (from, O_RDONLY);
  int tofd;
  ssize_t wrc;

  if (fromfd < 0) {
    fprintf (stderr, "Can't read file '%s' for copy: %s\n", 
	     from, strerror (errno));
  } else {
    tofd = open (to, O_CREAT | O_WRONLY, mode);
    if (tofd < 0) {
      fprintf (stderr, "Can't open file '%s' for writing: %s\n",
	       to, strerror (errno));
      close (fromfd);
    } else {
      rc = 1;
      while (rc > 0) {
	rc = read (fromfd, buf, BUFSZ);
	if (rc < 0) {
	  fprintf (stderr, "Error reading file '%s': %s\n",
		   from, strerror (errno));
	} else if (rc > 0) {
	  wrc = write (tofd, buf, rc);
	  if (wrc < 0) {
	    fprintf (stderr, "Error writing file '%s': %s\n",
		     to, strerror (errno));
	    rc = -1;
	  } else if (wrc != rc) {
	    fprintf (stderr, "Short write on file '%s'\n", to);
	    rc = -1;
	  }
	}
      }
      close (fromfd);
      close (tofd);
    }
  }
  return rc;
#undef BUFSZ
}

static int
do_moves ()
{
  const char *live_ldso = LDSO_LOCATION;
  const char *bkp_ldso = LDSO_LOCATION_BKP;
  const char *link_ldso = LDSO_LINK;
  char *bad_ldso_grave;
  size_t len;

  // leave some room for the suffix, etc.
  len = strlen (live_ldso) + 0x100;
  bad_ldso_grave = (char *) malloc (len);
  snprintf (bad_ldso_grave, len, "%s.flume.%lu", live_ldso, time (NULL));

  if (access (bkp_ldso, R_OK) != 0) {
    fprintf (stderr, "Failed to find backup ('%s')\n", bkp_ldso);
    return -1;
  }

  if (rename (live_ldso, bad_ldso_grave) != 0) {
    fprintf (stderr, "Failed to backup live ld.so ('%s') to '%s'\n", 
	     live_ldso, bad_ldso_grave);
  }

  if (my_copy (bkp_ldso, live_ldso, 0, 0, 0755) != 0) {
    fprintf (stderr, "Failed to recover ld.so (%s); "
	     "now you're totally hosed!\n", strerror (errno));
    return -1;
  }

  if (unlink (link_ldso) != 0) {
    fprintf (stderr, "No link found '%s': that's strange!\n",
	     link_ldso);
  }

  if (symlink (live_ldso, link_ldso) != 0) {
    fprintf (stderr, "Failed to make link %s -> %s: %s\n",
	     link_ldso, live_ldso, strerror (errno));
    return -1;
  }

  return 0;
}

int 
main (int argc, char *argv[])
{
  progname = argv[0];
  int ch;

  while ((ch = getopt (argc, argv, "h?")) != -1 ) {
    switch (ch) {
    case 'h':
    case 'g':
    default:
      usage ();
      break;
    }
  }

  argc -= optind;
  argv += optind;
    
  if (argc != 0) {
    usage ();
  }

  return do_moves ();
}
