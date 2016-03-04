#ifdef USE_FLUME
#include "flume_features.h" // must come before <sys/stat.h>
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef USE_FLUME
#include "flume_cpp.h"
#include "flume_prot.h"
#include "flume_api.h"
#include "flume_clnt.h"
#endif

#include "testlib.h"

#define MAX_FILES 1024
#define MAX_REPS 1024*64
#define BIGBUF 40960
static char buf[BIGBUF];
static char name[BUFLEN];

static char *prog_name;
static char *rodir;
static char *rwdir;

static int dir_reps;
static int file_reps;
static int num_dirs;
static int fds[MAX_FILES];
#ifdef USE_FLUME
static x_handle_t handles[MAX_REPS];
static x_label_t *slabel;
#endif

void usage () {
  fprintf (stderr, 
           "%s: {obsd|flume|createfiles} <readonlydir> <readwritedir> <flushsizeMB> <num_spreading_dirs> <num_files/reps>\n"
           "  output format is: operation num_files total_time avg_time (in secs)\n", prog_name);

  exit (1);
}

void report (const char *s, int n, double elapsed) {
  printf("%-15s\t%d\t% 5.3lf\t% 5.3lf\n", s, n, elapsed * (double)1000000, (elapsed / n) * 1000000);
}

void mkdir_test (int n) {
  int i;
  double elapsed;

  start ();
  for (i = 0; i < n; i ++) {
    filename_exists (0, name, BUFLEN, i);
    
    if(mkdir (name, 0777) < 0) {
      printf("%s: mkdir %d(%s) failed %d\n", prog_name, i, name, errno);
      exit(1);
    }
  }
  elapsed = stop ();
  report ("mkdir", n, elapsed);
}

void rmdir_test (int n) {
  int i;
  double elapsed;

  start ();
  for (i = 0; i < n; i ++) {
    filename_exists (0, name, BUFLEN, i);
    
    if(rmdir (name) < 0) {
      printf("%s: rmdir %d(%s) failed %d\n", prog_name, i, name, errno);
      exit(1);
    }
  }
  elapsed = stop ();
  report ("rmdir", n, elapsed);
}

void open_create_test (int n, int reportcreate) {
  int i, j, diff, rc;
  double elapsed = 0;

  for (j=0; j<n; j+=1000) {
    diff = min (n-j, 1000);
    start ();
    for (i = 0; i < diff; i ++) {
      filename_exists (0, name, BUFLEN, i+j);
      if((fds[i] = open(name, O_WRONLY | O_CREAT/* | O_TRUNC*/, /*S_IRWXU*/ 0644)) < 0) {
        printf("%s: create %d(%s) failed %d %d\n", prog_name, i, name,
               fds[i], errno);
        exit(1);
      }
    }
    elapsed += stop ();
    
    for (i=0; i<diff; i++) {
    }

    for (i = 0; i < diff; i ++) {
      if ((rc = write(fds[i], buf, 1024)) < 0) {
        printf("%s: write failed %d %d\n", prog_name, rc, errno);
        exit(1);
      }
      close (fds[i]);
    }
  }
  
  if (reportcreate)
    report ("open_create", n, elapsed);
}

void open_exists_test (int n, int readonly, int reportopen, int reportclose) {
  int i, j, diff;
  double open_elapsed = 0;
  double close_elapsed = 0;

  for (j=0; j<n; j+=1000) {
    diff = min (n-j, 1000);

    start ();
    for (i = 0; i < diff; i ++) {
      filename_exists (readonly, name, BUFLEN, i+j);

      if((fds[i] = open(name, O_RDONLY)) < 0) {
        printf("%s: open %d(%s) failed %d %d\n", prog_name, i, name,
               fds[i], errno);
        exit(1);
      }
    }
    open_elapsed += stop ();

    start ();
    for (i = 0; i < diff; i ++) {
      close (fds[i]);
    }
    close_elapsed += stop ();
  }

  if (reportopen) {
    if (readonly) 
      report ("open_exists(ro)", n, open_elapsed);
    else 
      report ("open_exists(rw)", n, open_elapsed);
  }
 if (reportclose)
   report ("close", n, close_elapsed);
}

void _open_noent_test (int num_files, int public) {
  int i, fd;
  for (i=0; i<num_files; i++) {
    filename_noent (name, BUFLEN, i, public);
    fd = open (name, O_RDONLY);
    if (fd < 0 && errno != ENOENT) {
      printf ("open returned error %d, errno %d\n", fd, errno);
      exit (1);
    }
  }
}

void open_noent_test (int num_files) {
  start ();
  _open_noent_test (num_files, 0);
  report ("open_noent", num_files, stop ());

  start ();
  _open_noent_test (num_files, 1);
  report ("open_noent(pub)", num_files, stop ());
}

void stat_test (int num_files, int readonly) {
  double elapsed;
  int i;
  struct stat sb;

  start ();
  for (i=0; i<num_files; i++) {
    filename_exists (readonly, name, BUFLEN, i);

    if (stat (name, &sb) < 0) {
      printf ("stat returned errno %d\n", errno);
      exit (1);
    }
  }
  elapsed = stop ();
  if (readonly)
    report ("stat(ro)", num_files, elapsed);
  else
    report ("stat(rw)", num_files, elapsed);
}

void unlink_test (int num_files, int benchmark) {
  double elapsed;
  int i, rc;

  if (benchmark)
    start ();
  for (i=0; i<num_files; i++) {
    filename_exists (0, name, BUFLEN, i);
    rc = unlink (name);
    if (rc < 0) {
      printf ("unlink returned error %d, errno %d\n", rc, errno);
      exit (1);
    }
  }
  if (benchmark) {
    elapsed = stop ();
    report ("unlink", num_files, elapsed);
  }
}

void symlink_test (int num_files) {
  double elapsed;
  int i, rc;
  char *linkval = "dummylinkvalue";

  start ();
  for (i=0; i<num_files; i++) {
    filename_exists (0, name, BUFLEN, i);
    rc = symlink (linkval, name);
    if (rc < 0) {
      printf ("symlink returned error %d, errno %d\n", rc, errno);
      exit (1);
    }
  }
  elapsed = stop ();
  report ("symlink", num_files, elapsed);
}

void readlink_test (int num_files) {
  double elapsed;
  int i, rc;

  start ();
  for (i=0; i<num_files; i++) {
    filename_exists (0, name, BUFLEN, i);
    rc = readlink (name, buf, BIGBUF);
    if (rc < 0) {
      printf ("readlink returned error %d, errno %d\n", rc, errno);
      exit (1);
    }
  }
  elapsed = stop ();
  report ("readlink", num_files, elapsed);
}

#ifdef USE_FLUME
void newhandle_test (int num_handles) {
  double elapsed;
  int i, rc;
  char *handlename = "testhandle";

  start ();
  for (i=0; i<num_handles; i++) {
    rc = flume_new_handle (&handles[i], HANDLE_OPT_DEFAULT_ADD, handlename);
    if (rc < 0) {
      printf ("flume_new_handle returned error %d, errno %d\n", rc, errno);
      exit (1);
    }
  }
  elapsed = stop ();
  report ("newhandle", num_handles, elapsed);
}

void setlabel_test (int num_handles) {
  int i, rc;

  if (label_resize (slabel, 1, 1) < 0) {
    printf ("label_resize returned error\n");
    exit (1);
  }

  start ();
  for (i=0; i<num_handles; i++) {
    if (label_set (slabel, 0, handles[i]) < 0) {
      printf ("label_set returned error\n");
      exit (1);
    }

    rc = flume_set_label (slabel, LABEL_S, 1);
    if (rc < 0) {
      printf ("flume_set_label returned error %d, errno %d\n", rc, errno);
      exit (1);
    }
  }

  /* make sure to clear this before printing/returning? */
  x_label_t *empty = label_alloc (0);
  flume_set_label (empty, LABEL_S, 1);
  flume_set_label (empty, LABEL_O, 1);

  report ("setlabel", num_handles, stop());
}

void flumenull_test (int nmsgs) {
  int i;

  start ();
  for (i=0; i<nmsgs; i++) {
    if (flume_null () < 0) {
      fprintf (stderr, "flume_null error\n");
      exit (1);
    }
  }
  report ("flumenull", nmsgs, stop());
}
#endif

int main (int argc, char *argv[]) {
  int flush_mb;
  char *mode;
  prog_name = argv[0];

  if (argc != 8)
    usage ();

  mode = argv[1];
  rodir = argv[2];
  rwdir = argv[3];
  flush_mb = atoi (argv[4]);
  num_dirs = atoi (argv[5]);
  dir_reps = atoi (argv[6]);
  file_reps = atoi (argv[7]);

  if (strcmp(mode, "obsd") && strcmp(mode, "flume") && strcmp(mode, "createfiles"))
    usage ();

  if (file_reps > MAX_REPS) {
    printf ("too many files!\n");
    usage ();
  }

  if (!strcmp(mode, "createfiles")) {
    init_test (prog_name, rodir, rodir, num_dirs, flush_mb);
    create_dirs ();
    open_create_test (file_reps, 0);
    /* leave the files around and exit */

  } else {

    /* Setup test enviornment */
    init_test (prog_name, rodir, rwdir, num_dirs, flush_mb);
    create_flush_file ();
    create_dirs ();
#ifdef USE_FLUME
    slabel = label_alloc (0);
#endif
    
    /* Run tests */
    mkdir_test (dir_reps);
    rmdir_test (dir_reps);
    
    open_create_test (file_reps, 1);
    open_exists_test (file_reps, 1, 1, 0);
    open_exists_test (file_reps, 0, 1, 1);
    open_noent_test (file_reps);
    stat_test (file_reps, 0);
    stat_test (file_reps, 1);
    unlink_test (file_reps, 1);
    symlink_test (file_reps);
    readlink_test (file_reps);
    unlink_test (file_reps, 0);
    
    /* Do some flume specific tests, which will alter our S label */
    
#ifdef USE_FLUME
    if (!strcmp (mode, "flume")) {
      newhandle_test (file_reps);
      setlabel_test (file_reps);
      flumenull_test (file_reps);
    }
#endif
    
    clean_dirs ();
#ifdef USE_FLUME
    label_free (slabel);
#endif
  }

  return 0;
}
