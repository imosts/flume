// -*-c++-*-
/* Accepts a username/password and requests a temporary password from
 * the user manager.  Sends the temporary password back to the client
 * browser as a cookie. */

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#include "async.h"
#include "tame.h"
#include "tame_io.h"
#include "flume_const.h"
#include "flumeutil.h"
#include "umgrclnt.h"
#include "generichelpers.h"
#include "moinhelpers.h"
extern "C" { 
#include "cgl.h"
#include "flume_internal.h"
}

#define USE_FROZEN 0
#define BUFLEN 1024
#define DELAY 3
extern char **environ;

static void
handle_create (str un, str pw)
{
  str uid, gid, tpw;
  str umgr = flume_umgr ();
  int rc;
  if ((rc = umgr_newuser_login (umgr, un, pw, uid, gid, tpw)))
    send_msg (str (strbuf("error in umgr_newuser_login %d, umgr=%s", 
                          rc, umgr.cstr ())));

  x_handle_t h;  /* request privs */
  if (handle_from_armor (gid.cstr(), &h) < 0)
    send_msg (str (strbuf("error parsing gid %s", gid.cstr())));
  if ((rc = flume_req_privs (h, tpw.cstr())) < 0)
    send_msg ("Error requesting moin I privs?\n");

  strbuf sb, dirname, filename;
  sb.fmt("aliasname=\n"
         "css_url=\n"
         "date_fmt=\n"
         "datetime_fmt=\n"
         "disabled=0\n"
         "edit_on_doubleclick=0\n"
         "edit_rows=20\n"
         "editor_default=text\n"
         "editor_ui=freechoice\n"
         "email=%s\n"
         "enc_password=\n"
         "language=\n"
         "last_saved=1172789703.05\n"
         "mailto_author=0\n"
         "name=%s\n"
         "quicklinks=\n"
         "remember_last_visit=0\n"
         "remember_me=1\n"
         "show_fancy_diff=1\n"
         "show_nonexist_qm=0\n"
         "show_page_trail=1\n"
         "show_toolbar=1\n"
         "show_topbottom=0\n"
         "subscribed_pages=\n"
         "theme_name=classic\n"
         "flm_offset=0\n"
         "want_trivial=0\n"
         "wikiname_add_spaces=0\n", un.cstr(), un.cstr());

  read_tags (un, uid);

  /* user's directory has S = {user.etag} I = {moin} */
  if ((rc = flume_expand_label (LABEL_S, me()->etag)) < 0) 
    send_msg (str (strbuf ("error %d expanding S label to include 0x%" PRIx64 "\n", rc, me()->etag)));
  if (add_env_itag_to_o (MOIN_I_ENV, MOIN_I_PW_ENV) < 0)
    send_msg ("could not add MOIN to O label");

  /* add user's export tag because once we increase I label, we won't
     be able to read our own group   */
  h = handle_construct (CAPABILITY_SUBTRACT | HANDLE_OPT_PERSISTENT | HANDLE_OPT_DEFAULT_ADD,
                        handle_base (me()->etag));
  if ((rc = flume_expand_label (LABEL_O, h)) < 0) 
    send_msg (str (strbuf ("error %d expanding O label to include 0x%" PRIx64 "\n", rc, h)));

  if (add_env_itag_to_i (MOIN_I_ENV) < 0)
    send_msg ("could not add MOIN to I label");

  vec<x_handle_t> itags, stags, otags;
  add_etag (&stags, me());
  if ((h = env_to_i_handle (MOIN_I_ENV, 0)) < 0)
    send_msg (str (strbuf ("could not read/parse %s", MOIN_I_ENV)));
  itags.push_back (h);
  x_labelset_t *ls = labelset_from_vecs (stags, itags, otags);

  /* make the user's directory and save their profile */
  dirname << MOIN_USERS << "/" << flume_labelset_to_filename(ls);
  if (flume_mkdir_full (str(dirname).cstr(), 0700, ls) < 0)
    send_msg (str (strbuf ("could not mkdir %s", str(dirname).cstr())));

  filename.fmt ("%s/profile", str(dirname).cstr());
  str2file (str(filename), str(sb));

  labelset_free (ls);
  set_cookies (un, uid, gid, tpw);
  output_redirect ("Success creating a new user", getenv("REQUEST_URI"), DELAY);
}
 
static void
handle_logout ()
{
  clear_cookies ();
  send_msg ("Successfully logged out");
}

static void
install_filters (char *filterfile) {
  x_filter_t *f = filter_alloc ();
  if (!filterfile)
    send_msg (str (strbuf ("Please define %s", filterfile)));
  if (flume_apply_filter (f, filterfile, LABEL_I) < 0)
    send_msg (str (strbuf ("could not install filter %s", filterfile)));
  filter_free (f);
}

static void
add_moinpath_i_tags_def (str path, vec<x_handle_t> &itags, str def) {
  /* Set I = {moin}, unless path specifies a different integrity */
  if (add_moinpath_tags (LABEL_I, path, itags) < 0)
    send_msg (str (strbuf ("error adding moinpath I tags for path %s", path.cstr())));
  
  if (itags.size() == 0) {
    x_handle_t h = env_to_i_handle (def.cstr(), 0);
    if (!h)
      send_msg (str (strbuf ("could not read/parse env %s", def.cstr())));
    itags.push_back (h);
  }
}

static void
add_allowwrite_otags (vec<x_handle_t> &v)
{
  const char *allowwrite = cgl_getvalue ("allowwrite");

  static rxx x ("\\s*,\\s*");
  vec<str> writers;
  split (&writers, x, allowwrite);
  for (unsigned i=0; i<writers.size(); i++) {
    FLUMEDBG4 (CLNT, CHATTER, "allowwriter %s\n", writers[i].cstr());
    principal_t *p = get_principal (writers[i]);
    if (p) {
      v.push_back (p->wtag);
    } else {
      send_msg (str (strbuf ("Could not translate username [%s] to write tag, you "
                             "probably dont have enough privs to create with the "
                             "specified O label.", writers[i].cstr())));
    }
  }
}

static void
get_readonly_privs (str un, str path, vec<x_handle_t> &stags, 
                    vec<x_handle_t> &otags, vec<x_handle_t> &itags)
{
  add_all_etags (stags);
  add_uetag (otags, me());
}

static void
get_edit_create_privs (str path, vec<x_handle_t> &stags, 
                       vec<x_handle_t> &otags, vec<x_handle_t> &itags)
{
  FLUMEDBG4 (CLNT, CHATTER, "editing path: [%s]\n", path.cstr());
  add_moinpath_tags (LABEL_S, path, stags);

  /* Allow the editor to read user's profile & tags file unless the
   * tag is in S */
  if (!contains_tag (stags, me()->uetag))
    otags.push_back (handle_construct (CAPABILITY_SUBTRACT | 
                                       HANDLE_OPT_PERSISTENT | 
                                       HANDLE_OPT_DEFAULT_ADD, 
                                       handle_base (me()->uetag)));
  if (!contains_tag (stags, me()->etag))
    otags.push_back (handle_construct (CAPABILITY_SUBTRACT | 
                                       HANDLE_OPT_PERSISTENT | 
                                       HANDLE_OPT_DEFAULT_ADD, 
                                       handle_base (me()->etag)));

  if (cgl_getvalue ("create")) {
    /* Creating a new page, figure out what writeprotect tags are
     * supposed to on this page */
    add_allowwrite_otags (otags);
  } else {
    /* editing an existing page, just match the file's otags */
    add_moinpath_tags (LABEL_O, path, otags);
  }
}

static x_labelset_t *
get_needed_privs (const char *path, const char *action, const char *un, const char *uid)
{
  FLUMEDBG4 (CLNT, CHATTER, "Determining privs for path %s, action %s\n", path, action);
  vec<x_handle_t> itags, stags, otags;
  add_moinpath_i_tags_def (path, itags, MOIN_I_ENV);

  if (uid) {
    read_tags (un, uid);
    if (!strcmp (action, "edit")) {
      get_edit_create_privs (path, stags, otags, itags);
    } else 
      get_readonly_privs (un, path, stags, otags, itags);
  }

  x_labelset_t *moinlabs = labelset_from_vecs (stags, itags, otags);
  if (!moinlabs)
    send_msg ("could not translate tags");
  return moinlabs;
}

static void
set_moinlaunch_privs (x_labelset_t *moinlabs) {
  /* set our own I, S, O labels so we can get the response */
  int rc;
  unsigned i;

  install_filters (getenv (UMGR_MOIN_FILTER_ENV));
  if (label_contains (&moinlabs->I, env_to_i_handle (CLASSIC_I_ENV, 0)))
    install_filters (getenv (MOIN_CLASSIC_FILTER_ENV));
  if (label_contains (&moinlabs->I, env_to_i_handle (RIGHTSIDEBAR_I_ENV, 0)))
    install_filters (getenv (MOIN_RIGHTSIDEBAR_FILTER_ENV));

  /* Add everything in moin's O label to our O label (even though we
     have it in our group.  This is a hack because filters dont work
     for groups yet */
  for (i=0; i<moinlabs->O->len; i++)
    if ((rc = flume_expand_label (LABEL_O, moinlabs->O->val[i])) < 0)
      send_msg (str (strbuf ("Error expanding O label to include 0x%" PRIx64, 
                             moinlabs->O->val[i])));

  /* Add everything in moin's S label to our O label so that the RM
     doesn't need to traverse our group.  It will be illegal to
     traverse our group after we increase our I label.  */
  for (i=0; i<moinlabs->S.len; i++) {
    x_handle_t h = handle_construct (CAPABILITY_SUBTRACT | HANDLE_OPT_PERSISTENT | HANDLE_OPT_DEFAULT_ADD,
                                   handle_base (moinlabs->S.val[i]));
    if ((rc = flume_expand_label (LABEL_O, h)) < 0)
      send_msg (str (strbuf ("Error expanding O label to include 0x%" PRIx64, h)));
  }

  /* Add everything in moin's S label to our S label (before setting I label) */
  if ((rc = flume_set_label (&moinlabs->S , LABEL_S, 1)) < 0)
    send_msg ("Error setting moinlaunch S label");

  /* Add integrity tags if necessary */
  if (label_contains (&moinlabs->I, env_to_i_handle (CLASSIC_I_ENV, 0)))
    if (add_env_itag_to_o (CLASSIC_I_ENV, CLASSIC_I_PW_ENV) < 0)
      send_msg (str (strbuf ("could not add %s to O label", CLASSIC_I_ENV)));
  if (label_contains (&moinlabs->I, env_to_i_handle (RIGHTSIDEBAR_I_ENV, 0)))
    if (add_env_itag_to_o (RIGHTSIDEBAR_I_ENV, RIGHTSIDEBAR_I_PW_ENV) < 0)
      send_msg (str (strbuf ("could not add %s to O label", RIGHTSIDEBAR_I_ENV)));
  if (label_contains (&moinlabs->I, env_to_i_handle (MOIN_I_ENV, 0)))
    if (add_env_itag_to_o (MOIN_I_ENV, MOIN_I_PW_ENV) < 0)
      send_msg ("could not add MOIN to O label");

  if (flume_set_label (&moinlabs->I, LABEL_I, 1) < 0)
    send_msg ("could not set I label to equal moin");
}

tamed static void
handle_launch (const char *path, const char *action, const char *un, 
               const char *uid, const char *gid, const char *tpw)
{
  tvars {
    int rc;
    x_labelset_t *moinlabs;
    x_handle_t h;
    str s;
  }

  /* req privs with cookie */
  if (un) {
    if (handle_from_armor (gid, &h) < 0)
      send_msg (str (strbuf ("Error parsing cookie's gid %s, %s", gid, s.cstr())));

    FLUMEDBG4 (CLNT, CHATTER, "Requesting privs, (gid, tpw) (%s = %" PRIx64 ", %s)\n", gid, h, tpw);
    if ((rc = flume_req_privs (h, tpw)) < 0) {
      fprintf (stderr, "Error %d requesting privs, maybe your gid/tpw pair "
               "is wrong or expired (%s, %" PRIx64 ", %s)\n", rc, gid, h, tpw);
      un = uid = gid = tpw = NULL;
    } else {
      FLUMEDBG4 (CLNT, CHATTER, "moinlaunch got privs for user %s\n", un); 
      setenv ("FLUME_UID", uid, 1); /* notifies moin that user is logged in */
    }
  }
  
  /* figure out what labels to give moin, and moinlauncher */
  moinlabs = get_needed_privs(path, action, un, uid);
  set_moinlaunch_privs (moinlabs);
  if (0 || FLUMEDBG2 (CLNT)) {
    flume_dump_labels (stderr);
    labelset_print (stderr, "  launching moin with", moinlabs);
  }

  /* see if user can read this file */
  if (check_link_labels (path) < 0)
    send_msg (str (strbuf ("Could not translate security label to view [%s], "
                           "you're probably not allowed to read this page.", path)));

  /* spawn moin */
  twait { spawn_child (moinlabs, USE_FROZEN ? NULL : PYTHON, 
                       moin_cgi (USE_FROZEN), mkevent ()); }

  labelset_free (moinlabs);
  exit (0);
}

int
main (int argc, char *argv[])
{
  int rc, ctlsock, n;
  const char *un, *pw, *uid, *gid, *tpw, *action, *path;
  str s;
  set_debug_flags ();

  if ((n = fcntl (STDIN, F_GETFL)) < 0 || fcntl (STDIN, F_SETFL, n & ~O_NONBLOCK) < 0)
    send_msg ("Error clearing NONBLOCK");

  if ((rc = cgl_init()) < 0)
    send_msg ("Error initializing cgl library");

  if ((ctlsock = flume_myctlsock ()) < 0)
    send_msg ("Could not connect to RM, check that RM is running.");

  if (!(action = cgl_getvalue ("action")))
    action = "show";
  if (!(path = getenv ("PATH_INFO"))) 
    path = "/";

  un = cgl_getvalue ("username");
  pw = cgl_getvalue ("password");

  /* User is either logging in, logging out, already logged in, or surfing anonymously */
  if (!strcmp (action, "login") && cgl_getvalue("name") && cgl_getvalue("password")) {
    generic_login (un, pw, getenv ("REQUEST_URI"), DELAY);
  }  else if (!strcmp (action, "logout")) {
    handle_logout ();
    return NULL;

  } else if (!strcmp (action, "createuser")) {
    char *submit = cgl_getvalue ("submit");

    if (submit) {
      if (!strcmp (submit, SUBMIT_CREATE)) {
        if (!un || !pw)
          send_msg ("empty username or password");
        handle_create (un, pw);
      } else
        send_msg ("invalid createuser call");
    } else 
      send_create_form ("/cgi-bin/moinlaunch");

  } else if ((un = cgl_getcookie (UN_COOKIE)) && 
             (uid = cgl_getcookie (UID_COOKIE)) && 
             (gid = cgl_getcookie (GID_COOKIE)) && 
             (tpw = cgl_getcookie (TPW_COOKIE))) {

    /* check that UN actually maps to UID */
    str _uid = name2uid (flume_umgr(), un);
    if (!_uid || _uid != uid)
      send_msg (str (strbuf ("You supplied username %s and UID %s, but they do not match "
                             "the umgr's, or the umgr does not have that uid", un, uid)));
    handle_launch (path, action, un, uid, gid, tpw);
  } else {
    handle_launch (path, action, NULL, NULL, NULL, NULL);
  }

  amain ();
  return 0;
}
 
