// -*-c++-*-
/* A generic launcher for wikicode */

#include "tame.h"
#include "rxx.h"
#include "flume_const.h"
#include "flume_cpp.h"
#include "flume_ev_debug_int.h"
#include "htmlutil.h"
#include "generichelpers.h"
#include "umgrclnt.h"
extern "C" { 
#include "cgl.h"
#include "flume_internal.h"
#include "flume_clnt.h"
}
#include "wclaunch.h"

void
wclaunch::read_cookies () {
  /* If the cookies are invalid, then just ignore them and clear them */
  int rc;
  x_handle_t h;
  cookie_un = cgl_getcookie (UN_COOKIE);
  cookie_uid = cgl_getcookie (UID_COOKIE);
  cookie_gid = cgl_getcookie (GID_COOKIE);
  cookie_tpw = cgl_getcookie (TPW_COOKIE);

  if (!cookie_un || !cookie_uid || !cookie_gid || !cookie_tpw) {
    cookie_un = cookie_uid = cookie_gid = cookie_tpw = NULL;
    clear_cookies ();
    return;
  }

  str uid = name2uid (flume_umgr(), cookie_un);
  if (!uid) {
    send_msg ("Umgr could not find uid for supplied username '%s'.",
              htmlescape (cookie_un).cstr());
    cookie_un = cookie_uid = cookie_gid = cookie_tpw = NULL;
    clear_cookies ();
    return;
  }

  if (uid != cookie_uid) {
    send_msg ("You supplied username %s and UID %s, but they do not match "
              "the umgr's, or the umgr does not have that uid", 
              htmlescape (cookie_un).cstr(), htmlescape (uid).cstr());
    cookie_un = cookie_uid = cookie_gid = cookie_tpw = NULL;
    clear_cookies ();
    return;
  }

  if (handle_from_armor (cookie_gid, &h) < 0)
    send_msg ("Error parsing cookie's gid %s", htmlescape(cookie_gid).cstr());
  if ((rc = flume_req_privs (h, cookie_tpw.cstr())) < 0)
    send_msg ("Error requesting privs, maybe your cookies are expired\n");
  if (!(_me = read_user_tags (cookie_un, cookie_uid, &_name2tags)))
    send_msg ("Error reading tags");
  
  setenv ("FLUME_UID", cookie_uid, 1); /* pass UID to child */
}

int
wclaunch::logged_in () {
  return (cookie_un && cookie_uid && cookie_gid && cookie_tpw);
}

static x_labelset_t *
str2labelset (str s) {
  /* Translates string labelset from the URI to an x_labelset_t
   *   <s> looks like this "s,i,o" eg: "aaaaaaaaaaaaa,9ipsaaaaaaaba,9epsaaaaaaaba"
   *   (three frozen armored labels)
   */

  

  return labelset_alloc ();
}

int
wclaunch::parse_uri (str req) {
  /* request_uris look like this: /static/s1,i1,o1/s2,i2,o2/yipal/foo.gif  
   * s1 is from 
   */

  static rxx slash ("/");
  vec<str> v;
  split (&v, slash, req);

  if (v.size () < 2)
    return -1;

  if (v[0] != "")
    return -2;

  if (v[1] == MODE_TRUSTED || v[1] == MODE_STATIC ||
      v[1] == MODE_EXEC || v[1] == MODE_PYTHON) {
    req_mode = v[1];
  } else {
    return -3;
  }

  if (req_mode == MODE_STATIC || req_mode == MODE_EXEC || req_mode == MODE_PYTHON) {
    if (v.size () != 6)
      return -4;

    static rxx foo_rxx ("/(static|exec|python)/(\\w*,\\w*,\\w*)/(\\w*,\\w*,\\w*)/(\\w+)/(\\w+)$");
    if (foo_rxx.match (req)) {
      page1_ls = str2labelset (foo_rxx[2]);
      page2_ls = str2labelset (foo_rxx[3]);
      req_user = foo_rxx[4];
      req_file = foo_rxx[5];
    } else {
      return -5;
    }
  }

  if (illegal_filename (req_mode) ||
      illegal_filename (req_user) ||
      illegal_filename (req_file))
    send_msg ("illegal substrings in path: %s", htmlescape (req).cstr());

  if (illegal_username (req_user)) 
    send_msg ("illegal username: %s", htmlescape (req_user).cstr());

  return 0;
}



x_labelset_t *
wclaunch::script_labelset () {
  /* Return labelset for script as listed in the user's label map.
   * The labelmap file is formated like this "testuser s,i,o"  */
  x_labelset_t *ls = labelset_alloc ();

  if (cookie_uid) {
    str fname = strbuf().fmt ("%s/noi/labelmap", uid_to_homedir (cookie_uid).cstr());
    str labelmap = file2str (fname);

    if (labelmap) {
      static rxx split_lines ("\\s*\n\\s*", "m");
      static rxx parse_line ("^\\s*(\\w+)\\s+(\\w+)\\s*,\\s*(\\w+)\\s*,\\s*(\\w+)\\s*$");
      
      vec<str> lines;
      split (&lines, split_lines, labelmap);
      for (unsigned idx=0; idx<lines.size(); idx++) {
        x_label_t *ol = label_alloc (0);
        x_handle_t s, i, o;

        if (parse_line.match (lines[idx])) {
          if (req_user == parse_line[1]) {
            if (handle_from_armor (parse_line[2], &s) < 0 || 
                flume_thaw_label (labelset_get_S(ls), &s) < 0)
              send_msg ("error unfreezing S label");

            if (handle_from_armor (parse_line[3], &i) < 0 || 
                flume_thaw_label (labelset_get_I(ls), &i) < 0)
              send_msg ("error unfreezing I label");

            /* Handle O label differently cuz its not allocated by labelset_alloc */
            if (handle_from_armor (parse_line[4], &o) < 0 || 
                flume_thaw_label (ol, &o) < 0)
              send_msg ("error unfreezing O set");

            if (labelset_set_O (ls, ol) < 0)
              send_msg ("error setting O label");
          }
        } else {
          fprintf (stderr, "error while parsing labelmap\n");
        }
      }
    } else {
      fprintf (stderr, "no labelmap file\n");
    }
  } else {
    fprintf (stderr, "no cookie_uid\n");
  }

  return ls;
}

void
wclaunch::handle_static () {}

void
wclaunch::handle_exec () {}

tamed void
wclaunch::handle_python (cbv cb) {
  tvars {
    str script_file;
    x_labelset_t *child_labs;
  }

  child_labs = script_labelset ();
  labelset_print (stderr, "child labelset", child_labs);

  script_file = strbuf ().fmt ("%s/useri/scripts/%s",
                               uname_to_homedir (flume_umgr (), req_user).cstr(),
                               req_file.cstr());

  twait { spawn_child (child_labs, "/usr/bin/python", script_file, mkevent ()); }

  labelset_free (child_labs);
  cb->trigger ();
}

tamed void
wclaunch::start () {
  int n, rc, ctlsock;
  set_debug_flags ();

  if ((n = fcntl (STDIN, F_GETFL)) < 0 || fcntl (STDIN, F_SETFL, n & ~O_NONBLOCK) < 0)
    send_msg ("Error clearing NONBLOCK");

  if ((rc = cgl_init()) < 0)
    send_msg ("Error initializing cgl library");

  if ((ctlsock = flume_myctlsock ()) < 0)
    send_msg ("Could not connect to RM, check that RM is running.");

  request_uri = expect_env2str ("REQUEST_URI");
  path_info = expect_env2str ("PATH_INFO");

  if ((rc = parse_uri (request_uri)) < 0) 
    send_msg ("Error (%d) parsing REQUEST_URI: %s", rc, htmlescape (request_uri).cstr ());

  read_cookies ();

  if (req_mode == MODE_TRUSTED) {
    handle_trusted ();
  } else if (req_mode == MODE_STATIC) {
    handle_static ();
  } else if (req_mode == MODE_EXEC) {
    handle_exec ();
  } else if (req_mode == MODE_PYTHON) {
    twait { handle_python (mkevent ()); }
  } else {
    send_msg ("Unexpected mode error");
  }
  exit (0);
}

int
main (int argc, char *argv[]) {
  ptr<wclaunch> wc = New refcounted<wclaunch> ();
  wc->start ();
  amain ();
  return 0;
}
