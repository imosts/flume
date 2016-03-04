// -*-c++-*-
/* Methonds for handling "trusted" operations like 
 *  Creating new users
 *  Logging in
 *  Uploading scripts
 */

#include "flumeutil.h"
#include "htmlutil.h"
#include "umgrclnt.h"
#include "generichelpers.h"
extern "C" { 
#include "cgl.h"
#include "flume_internal.h"
#include "flume_clnt.h"
}
#include "wclaunch.h"

void
wclaunch::handle_create (str un, str pw) {
  str uid, gid, tpw;
  int rc;
  str umgr = flume_umgr ();

  if ((rc = umgr_newuser_login (umgr, un, pw, uid, gid, tpw)))
    send_msg ("error in umgr_newuser_login %d, umgr=%s", rc, htmlescape (umgr).cstr ());

  x_handle_t h;  /* request privs */
  if (handle_from_armor (gid.cstr(), &h) < 0)
    send_msg ("error parsing gid %s", htmlescape (gid).cstr());
  if ((rc = flume_req_privs (h, tpw.cstr())) < 0)
    send_msg ("Error requesting privs\n");
  
  set_cookies (un, uid, gid, tpw);
  output_redirect ("Success creating a new user", getenv("REQUEST_URI"), 3);
}

void
wclaunch::handle_login (str un, str pw) {
  generic_login (un, pw, request_uri, 3);
}

void
wclaunch::send_upload_form () {
  
  cgl_html_header ();
  cgl_html_begin ("Write a script");
  fprintf (stdout,
           "<h2>Write a script</h2>\n"
           "<form action=/%s method=post>\n"
           "<input type=text name=%s value=test.py><BR>\n"
           "<textarea name=%s rows=\"20\" cols=\"80\">"
           "print 'Content-Type: text/html\\r\\n\\r\\n'\nprint 'Hello World\\r\\n'\n"
           "</textarea><BR>\n"
           "<input type=submit name=%s value=%s>\n"
           "<input type=hidden name=%s value=%s>\n"
           "</form>", 
           MODE_TRUSTED, 
           ARG_FNAME, 
           ARG_TEXT, 
           ARG_SUBMIT, SUBMIT_SUBMIT,
           ARG_ACTION, ACTION_UPLOAD);
  cgl_html_end ();
  exit (0);
}

void
wclaunch::handle_upload () {
  /* Create or modify a script with I = {itag} O = {wtag} */

  str fname = cgl_getvalue (ARG_FNAME);
  str text = cgl_getvalue (ARG_TEXT);
  str scriptdir = strbuf().fmt ("%s/useri/scripts", 
                                uid_to_homedir (cookie_uid).cstr());

  if (illegal_filename (fname))
    send_msg ("Illegal characters in filename '%s'", htmlescape (fname).cstr ());

  /* Setup I label */
  int rc;
  x_labelset_t *scripts_ls = labelset_alloc ();
  vec<x_handle_t> s, i, o;
  i.push_back (_me->itag);
  o.push_back (_me->wtag);
  scripts_ls = labelset_from_vecs (s, i, o);

  if (flume_set_label (labelset_get_I (scripts_ls), LABEL_I, 1) < 0)
    send_msg ("could not set label");

  /* Create the scripts directory if necessary */
  x_labelset_t *foo = labelset_alloc ();
  if (((rc = flume_stat_file (foo, scriptdir.cstr ())) < 0) && 
      (flume_get_flm_errno () == FLUME_ENOENT)) {
    fprintf (stderr, "scripts directory does not exist, creating it.\n");

    if (flume_mkdir_full (scriptdir.cstr (), 0755, scripts_ls) < 0)
      send_msg ("Could not mkdir %s, flume_errno %d", 
                scriptdir.cstr (), flume_get_flm_errno ());
  } else if (rc < 0)
    send_msg ("Error stating scripts directory");
  labelset_free (foo);

  /* Write the script file */
  str script_file = strbuf().fmt ("%s/%s", scriptdir.cstr(), fname.cstr());
  if (flume_writefile (script_file.cstr(), O_CREAT | O_TRUNC | O_WRONLY , 
                       0755, scripts_ls, text.cstr(), text.len()) < 0)
    send_msg ("Error writing script");
  
  clear_label (LABEL_I);
  labelset_free (scripts_ls);
  send_msg ("Success");
}

void
wclaunch::send_control_panel () {
  send_upload_form ();
}

void
wclaunch::handle_trusted () {
  str submit = cgl_getvalue (ARG_SUBMIT);
  str action = cgl_getvalue (ARG_ACTION);

  if (logged_in ()) {
    if (!action) 
      action = ACTION_CONTROL;
  } else {
    action = ACTION_LOGINCREATE;
  }

  if (action == ACTION_CONTROL) {
    send_control_panel ();
    
  } else if (action == ACTION_UPLOAD) {
    if (submit && (submit != SUBMIT_SUBMIT))
      send_msg ("invalid Submit value: %s", submit.cstr());
    handle_upload ();

  } else if (action == ACTION_LOGINCREATE) {
    if (submit && (submit == SUBMIT_CREATE || submit == SUBMIT_LOGIN)) {
      str un = cgl_getvalue (ARG_UN);
      str pw = cgl_getvalue (ARG_PW);
      if (!un || !pw)
        send_msg ("invalid UN or PW");

      if (submit == SUBMIT_CREATE) 
        handle_create (un, pw);
      else
        handle_login (un, pw);
    } else if (submit) {
      send_msg ("invalid submit value: %s", htmlescape (submit).cstr ());
    } else {
      send_logincreate_form (strbuf ("/%s", MODE_TRUSTED));
    }
  } else {
    send_msg ("Unexpected action: %s", htmlescape (action).cstr ());
  }
}

