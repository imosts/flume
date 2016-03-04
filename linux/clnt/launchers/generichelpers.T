// -*-c++-*-
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <string.h>

#include "async.h"
#include "tame.h"
#include "tame_io.h"
#include "flume_cpp.h"
#include "flume_ev_debug_int.h"
#include "flume_const.h"
#include "umgrclnt.h"
#include "htmlutil.h"
#include "generichelpers.h"
#include "umgrclnt.h"
extern "C" { 
#include "cgl.h"
#include "flume_internal.h"
#include "flume_clnt.h"
}

#define CX(x) strdup(x)

str _flume_umgr;

void
send_msg (const char *args, ...)
{
  va_list ap;

  cgl_html_header ();
  cgl_html_begin ("Launcher Message");
  fprintf (stdout, "<h2>Launcher Message</h2>\n");
  fprintf (stdout, "MSG: ");

  va_start (ap, args);
  vfprintf (stdout, args, ap);
  va_end (ap);

  fprintf (stdout, "\n");
  cgl_html_end();
  exit(0);
}

void
output_redirect (str msg, str url, unsigned int delay)
{
  cgl_html_header ();
  cgl_html_begin ("Launcher");
 
  fprintf (stdout, 
           "<head><META HTTP-EQUIV=\"Refresh\" CONTENT=\"%d; "
           "URL=\'%s\'\"></head>\n", delay, url.cstr () );
  fprintf (stdout, "<h2>Launcher: %s, now redirecting</h2>\n", msg.cstr ());
  fprintf (stdout, "You will be redirected in %d seconds</p>\n", delay);
  cgl_html_end();
  exit(0);
}

void
send_create_form (str form)
{
  cgl_html_header ();
  cgl_html_begin ("Create User");
  fprintf (stdout,
           "<h2>Create a new user</h2>\n"
           "<p>Enter your username and password to create a new account</p>\n"
           "<form action=%s method=post>\n"
           "<table>"
           "<tr><td>Username:</td><td><input type=text name=username size=20 value='testuser'></td></tr>\n"
           "<tr><td>Password:</td><td><input type=text name=password size=20 value='pw'></td></tr>\n"
           "</table>"
           "<input type=submit name=submit value=Create>\n"
           "<input type=hidden name=action value=createuser>\n"
           "</form>\n", form.cstr ());
  cgl_html_end ();
  exit (0);
}

void
send_logincreate_form (str form)
{
  cgl_html_header ();
  cgl_html_begin ("Login or Create User");
  fprintf (stdout,
           "<h2>Login</h2>\n"
           "<form action=%s method=post>\n"
           "<table>"
           "<tr><td>Username:</td><td><input type=text name=username size=20 value='testuser'></td></tr>\n"
           "<tr><td>Password:</td><td><input type=text name=password size=20 value='pw'></td></tr>\n"
           "</table>"
           "<input type=submit name=submit value=%s>\n"
           "<input type=hidden name=action value=%s>\n"
           "</form>\n", form.cstr (), SUBMIT_LOGIN, ACTION_LOGINCREATE);

  fprintf (stdout,
           "<h2>Create a new user</h2>\n"
           "<p>Enter your username and password to create a new account</p>\n"
           "<form action=%s method=post>\n"
           "<table>"
           "<tr><td>Username:</td><td><input type=text name=username size=20 value='testuser'></td></tr>\n"
           "<tr><td>Password:</td><td><input type=text name=password size=20 value='pw'></td></tr>\n"
           "</table>"
           "<input type=submit name=submit value=%s>\n"
           "<input type=hidden name=action value=%s>\n"
           "</form>\n", form.cstr (), SUBMIT_CREATE, ACTION_LOGINCREATE);
  cgl_html_end ();
  exit (0);
}

void
set_cookies (str un, str uid, str gid, str tpw)
{
  time_t t;
  char *cookietime;

  time (&t);
  t += 60 * 60 * 24;
  cookietime = cgl_cookietime (&t);

  const char *s = "/";

  cgl_put_cookie (UN_COOKIE, (char *)un.cstr(), cookietime, s, NULL, 0);
  cgl_put_cookie (UID_COOKIE, (char *)uid.cstr(), cookietime, s, NULL, 0);
  cgl_put_cookie (GID_COOKIE, (char *)gid.cstr(), cookietime, s, NULL, 0);
  cgl_put_cookie (TPW_COOKIE, (char *)tpw.cstr(), cookietime, s, NULL, 0);
}

void
clear_cookies ()
{
  time_t t;
  char *cookietime = cgl_cookietime (&t);
  t -= 60;

  const char *s ="/";
  cgl_put_cookie (UID_COOKIE, "", cookietime, s, NULL, 0);
  cgl_put_cookie (GID_COOKIE, "", cookietime, s, NULL, 0);
  cgl_put_cookie (TPW_COOKIE, "", cookietime, s, NULL, 0);
}

str flume_umgr () {
  if (!_flume_umgr)
    _flume_umgr = getenv (UMGR_ID_ENV);
  return _flume_umgr;
}


str
expect_env2str (str s) {
  char *r;
  if (!(r = getenv ("REQUEST_URI")))
    send_msg ("%s undefined", s.cstr ());
  return r;
}

void
generic_login (str un, str pw, str path, int delay)
{
  int rc;
  str s, uid, gid, tpw, umgr;

  if (!un)
    send_msg ("failure: loggging without a username!");
  if (!pw)
    send_msg ("failure: loggging without a password!");

  if ((umgr = cgl_getvalue ("umgr"))) {
    /* Verify usermanagers match for debugging */
    s = strbuf ("%s/%s/setuid/umgr.py.suwrp", IHOME, flume_umgr ().cstr());
    if (strcmp (umgr, s.cstr()))
      send_msg ("failure: application is using a different umgr from launch! "
                "fix application and recompile %s != %s", 
                htmlescape(umgr).cstr(), htmlescape(s).cstr());
  }

  if ((rc = umgr_login (flume_umgr (), un, pw, uid, gid, tpw)))
    send_msg (str (strbuf ("failure: could not login, code %d", rc)));
      
  set_cookies (un, uid, gid, tpw);
  output_redirect ("You're logged in", path, delay);
}

bool
illegal_filename (str s) {
  vec<str> illegals;
  illegals.push_back ("/");
  illegals.push_back ("..");

  if (s)
    for (size_t i=0; i<illegals.size(); i++)
      if (strstr (s.cstr(), illegals[i].cstr()))
        return true;
  return false;
}

bool
illegal_username (str s) {
  if (illegal_filename (s))
    return true;

  vec<str> illegals;
  illegals.push_back ("none");

  if (s)
    for (size_t i=0; i<illegals.size(); i++)
      if (s == illegals[i])
        return true;
  return false;
}

tamed void
spawn_child (x_labelset_t *child_labs, str exec, str script, cbv cb) {
  tvars {
    int i(0), rc, fds[3], rcs[3];
    x_handle_t pid;
    x_handlevec_t *fdhandles;
    const char *argv[3];
  }
  
  if (exec) 
    argv[i++] = exec.cstr ();
  argv[i++] = script.cstr ();
  argv[i++] = NULL;

  /* clear cookies so moin learns nothing sensitive */
  setenv ("HTTP_COOKIE", "", 1);

  /* make socketpairs for stdin, stdout, stderr */
  fdhandles = label_alloc (3);
  rcs[0] = flume_socketpair (DUPLEX_ME_TO_THEM, &fds[0], &fdhandles->val[0], "stdin");
  rcs[1] = flume_socketpair (DUPLEX_THEM_TO_ME, &fds[1], &fdhandles->val[1], "stdout");
  rcs[2] = flume_socketpair (DUPLEX_THEM_TO_ME, &fds[2], &fdhandles->val[2], "stderr");
  if (rcs[0] < 0 || rcs[1] < 0 || rcs[2] < 0) {
    FLUMEDBG3(CLNT, ERROR, "could not create proxy socketpair\n");
    send_msg ("Error creating socketpair");
  }
  
  rc = flume_spawn_legacy (&pid, argv[0], (char *const*) argv,
			   environ, 3, 0, child_labs, fdhandles, NULL);
  if (rc < 0)
    send_msg ("error spawning child %s %s", exec.cstr (), script.cstr ());

  /* send form information to child */
  if (cgl_form_len ()) {
    rc = write (fds[0], cgl_form_data (), cgl_form_len ());
    if (rc < cgl_form_len ())
      send_msg ("Error sending form data to child");
  }

  make_async (fds[0]);
  make_async (fds[1]);
  make_async (fds[2]);
  make_async (STDIN);
  make_async (STDOUT);
  make_async (STDERR);

  /* proxy streams for child */
  twait {
    tame::proxy (STDIN, fds[0], mkevent ());
    tame::proxy (fds[1], STDOUT, mkevent ());
    tame::proxy (fds[2], STDERR, mkevent ());
  }

  cb->trigger ();
}
