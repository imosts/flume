// -*-c++-*-

/* Launches an untrusted CGI program in a confined flume enviornment.
 *   1) sets up the control socket with reference monitor
 *      set env variable FLUME_CTL_SOCKET to socket fd to RM
 *   2) exec the flumeed process (within the jail)
 */

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#include "async.h"
#include "tame.h"
#include "tame_io.h"
#include "flume_cpp.h"
#include "flume_prot.h"
#include "flume_ev_debug_int.h"
extern "C" { 
#include "flume_api.h"
#include "flume_clnt.h"
#include "cgl.h"
}

extern char **environ;

static struct timeval start_tv;
static struct timeval last_tv;
static unsigned long long 
timediff (struct timeval *x, struct timeval *y)
{
  unsigned long long x1, y1;
  x1 = ((unsigned long long)x->tv_sec * 1000000ULL + (unsigned long long)x->tv_usec);
  y1 = ((unsigned long long)y->tv_sec * 1000000ULL + (unsigned long long)y->tv_usec);
  return x1 - y1;
}
static void
init_timer ()
{
  if (!FLUMEDBG2 (PROFILE))
    return;
  gettimeofday (&last_tv, NULL);
  fprintf (stderr, "cgilaunch_timing start %ld.%06ld\n", 
           last_tv.tv_sec, last_tv.tv_usec);
  start_tv = last_tv;
}

static void
print_time (const char *msg)
{
  struct timeval tv;
  if (!FLUMEDBG2 (PROFILE))
    return;

  gettimeofday (&tv, NULL);
  fprintf (stderr, "cgilaunch_timing %s %llu\n", msg, timediff (&tv, &last_tv));
  last_tv = tv;
}

static void
total_time ()
{
  struct timeval tv;
  if (!FLUMEDBG2 (PROFILE))
    return;

  gettimeofday (&tv, NULL);
  fprintf (stderr, "cgilaunch_timing total %llu\n", timediff (&tv, &start_tv));
}

static void
usage ()
{
  fprintf (stderr, "usage: cgilaunch [-t token] [-s flume_sock] "
           "program\n");
  exit(1);
}

static void
error_response (const char *msg)
{
  cgl_html_header ();
  cgl_html_begin ("Flume Error!");
  fprintf (stdout, "<h2>Flume Error!</h2>\n");
  fprintf (stdout, "MSG: %s\n", msg);
  cgl_html_end();
  exit(0);
}

static void
cgilaunch_login ()
{
  cgl_html_header ();
  cgl_html_begin ("CGI Launcher");
  fprintf (stdout, "<h2>CGI Launcher</h2>\n");
  fprintf (stdout, 
           "<form action=/cgi-bin/cgilaunch method=get>\n"
           "Handle: <input type=text name=UN size=80 value='0x45000000000005bb'><BR>\n"
           "Token: <input type=text name=PW size=80 value='mqxgd3gjze9v8bwcewfy38bvdp9qpd82'><BR>\n"
           "CGI program: <input type=text name=EXEC size=80 value=simplecgi><BR>\n"
           "<input type=submit name=Submit value=Submit>\n"
           "</form>\n");
  cgl_html_end();
  exit(0);
}

tamed static void
do_fork (x_handle_t S_handle, str exec_path)
{
  tvars {
    int input, output, err, rc;
    x_handle_t pid;
    x_label_t *S_label;
    x_labelset_t *labs;
    x_handlevec_t *fdhandles;
    const char *argv[5];
  }

  print_time ("do_fork1");
  /* setup command line arguments */
  argv[0] = exec_path.cstr();
  argv[1] = NULL;

  /* make socketpairs for stdin, stdout, stderr */
  fdhandles = label_alloc (3);
  rc = flume_socketpair (DUPLEX_ME_TO_THEM, &input, &fdhandles->val[0], "stdin");
  if (rc < 0) {
    FLUMEDBG4(CLNT, FATAL_ERROR, "could not create proxy stdin, err %d\n", errno);
    exit (-1);
  }
  rc = flume_socketpair (DUPLEX_THEM_TO_ME, &output, &fdhandles->val[1], "stdout");
  if (rc < 0) {
    FLUMEDBG4(CLNT, FATAL_ERROR, "could not create proxy stdout, err %d\n", errno);
    exit (-1);
  }
  rc = flume_socketpair (DUPLEX_THEM_TO_ME, &err, &fdhandles->val[2], "stderr");
  if (rc < 0) {
    FLUMEDBG4(CLNT, FATAL_ERROR, "could not create proxy stderr, err %d\n", errno);
    exit (-1);
  }
  print_time ("do_fork2");

  /* setup CGI's labelset */
  S_label = label_alloc (1);
  rc = label_set (S_label, 0, S_handle);
  if (rc < 0) 
    FLUMEDBG3(CLNT, FATAL_ERROR, "could not set label\n");
  labs = labelset_alloc ();
  rc = labelset_set_S (labs, S_label);
  if (rc < 0) 
    FLUMEDBG3(CLNT, FATAL_ERROR, "could not set labelset\n");
  print_time ("do_fork3");

  /* spawn the CGI and proxy its input/output */
  rc = flume_spawn_legacy (&pid, argv[0], (char *const*) argv, 
			   environ, 3, 0, labs, fdhandles, NULL);
  if (rc < 0) 
    FLUMEDBG4(CLNT, FATAL_ERROR, "error spawning CGI errno %d", errno);
  print_time ("do_fork4");


  /* send form information to cgi */
  if (cgl_form_len ()) {
    rc = write (input, cgl_form_data (), cgl_form_len ());
    if (rc < cgl_form_len ()) {
      FLUMEDBG4(CLNT, ERROR, "error %d sending form data to cgi", rc);
      error_response ("Error sending form data to cgi");
    }
  }

  twait {
    tame::proxy (STDIN, input, mkevent ());
    tame::proxy (output, STDOUT, mkevent ());
    tame::proxy (err, STDERR, mkevent ());
  }
  print_time ("do_fork5");
  total_time ();
  exit (0);
}

tamed static void
launch (const char *sockname, x_handle_t user_handle,
        const char *user_token, str exec_path)
{
  int rc;
  str tmp;
  x_handle_t h;

  print_time ("launch1");
  /* Setup Ownership and Secrecy labels */
  h = handle_construct (HANDLE_OPT_PERSISTENT |
                        CAPABILITY_SUBTRACT | 
                        HANDLE_OPT_DEFAULT_ADD, user_handle);

  rc = flume_req_privs (h, user_token);
  if (rc < 0)
    error_response ("error getting privileges, username/token may be incorrect "
                    "or RM may not be running\n");

  h = handle_construct (HANDLE_OPT_PERSISTENT | HANDLE_OPT_DEFAULT_ADD, 
                        user_handle);
  rc = flume_expand_label (LABEL_S, h);
  if (rc < 0) {
    FLUMEDBG4(CLNT, FATAL_ERROR, "error %d expanding S label %" PRIx64 "\n", 
	          errno, h);
    exit (-1);
  }
  
  print_time ("launch2");
  do_fork (h, exec_path);
}

int
main (int argc, char *argv[])
{
  const char *sockname = NULL;
  const char *username;
  
  x_handle_t user_handle;
  const char *user_token = NULL;
  const char *executable = NULL;

  set_debug_flags ();
  init_timer ();
  print_time ("main1");

  /* check FLUME variables */
  if (!sockname)
    sockname = getenv (FLUME_SCK_EV);
  if (!sockname) {
    FLUMEDBG4(CLNT, FATAL_ERROR, "you must define the rm socket, with the %s "
             "environment variable\n", FLUME_SCK_EV);
    usage();
  }

  /*
  s = getenv (FLUME_RGD_EV);
  if (!s || strcmp (s, "2")) {
    FLUMEDBG4(CLNT, FATAL_ERROR, "it is unsafe to launch a "
             "program not in Flume ring 2, and cgilaunch will not work "
             "in Flume ring 3.  Set %s to \"2\"\n", FLUME_RGD_EV);
    usage();
  }
  */

  /* Get CGI variables */
  int rc;
  if ((rc = cgl_init()) < 0) {
    FLUMEDBG4(CLNT, FATAL_ERROR, "cgl_init() error %d\n", rc);
    exit (-1);
  }
  
  if (!(username = cgl_getvalue("UN")) || !strcmp(username, ""))
    cgilaunch_login ();
  
  if (handle_from_str (username, &user_handle) < 0)
    error_response ("invalid username");
  
  if (!(user_token = cgl_getvalue("PW")))
    error_response ("user must supply login token: 'PW'");
  
  if (!(executable = cgl_getvalue("EXEC")))
    error_response ("user must supply an executable: 'EXEC'");

  if (strstr (executable, ".."))
    error_response ("executable name must not contain '..'\n");
  strbuf exec_path;
  exec_path << "/bin/" << executable;

  print_time ("main2");
  launch (sockname, user_handle, user_token, str(exec_path));
  amain ();
  return 0;
}
