// -*-c++-*-
#include "async.h"
#include "parseopt.h"
#include "flume_cpp.h"
#include "umgrclnt.h"
#include "flumeutil.h"
#include "flume_prot.h"
#include "flume_ev_debug_int.h"
#include "rxx.h"
extern "C" { 
#include "flume_clnt.h"
#include "flume_api.h"
}

static int to_umgr, from_umgr;
static str _uid, _gid, _tpw;

extern char **environ;

static rxx rc_rxx ("(\\d+).*\n", "m");

static int _connect (str umgr)
{
  x_labelset_t *umgrlabs = labelset_alloc ();
  x_handlevec_t *fdhandles = label_alloc (2);
  x_handle_t pid;
  strbuf sb;
  const char *argv[2];
  int rc, rcs[2], ret = 100;
  str s;
   
  /* make socketpairs for stdin, stdout, stderr */
  rcs[0] = flume_socketpair (DUPLEX_ME_TO_THEM, &to_umgr, &fdhandles->val[0], "stdout");
  rcs[1] = flume_socketpair (DUPLEX_THEM_TO_ME, &from_umgr, &fdhandles->val[1], "stdin");
  if (rcs[0] < 0 || rcs[1] < 0) {
    FLUMEDBG3(CLNT, ERROR, "could not create umgr socketpair\n");
    ret = 101;
    goto done;
  }

  sb.fmt ("/ihome/%s/setuid/umgr.py.suwrp", umgr.cstr());
  s = sb;
  argv[0] = s.cstr();
  argv[1] = NULL;

  rc = flume_spawn (&pid, argv[0], (char *const*) argv, 
		    environ, SPAWN_SETUID | SPAWN_CONFINED, 
		    fdhandles, NULL, NULL, NULL, NULL);
  if (rc < 0) {
    FLUMEDBG4(CLNT, ERROR, "error %d spawning umgr client", errno);
    ret = 102;
    goto done;
  }
  ret = 0;

 done:
  labelset_free (umgrlabs);
  label_free (fdhandles);
  return ret;
}

static int _disconnect ()
{
  u_int64_t pid;
  int rc = 0;
  int visable;
  close (to_umgr);
  close (from_umgr);

  flume_waitpid (&pid, &visable, &rc, 0, 0);
  return rc;
}

static int _newuser (str un, str pw) 
{
  strbuf sb;
  int rc;
   
  /* send request to user manager */
  sb.fmt ("newuser %s %s\n", un.cstr(), pw.cstr());
  if ((rc = sb.tosuio()->output (to_umgr)) < 0) {
    FLUMEDBG4(CLNT, ERROR, "error %d sending newuser request to umgr", rc);
    return 900;
  }
   
  /* get response from user manager */
  if ((rc = sb.tosuio()->input (from_umgr)) < 0) {
    FLUMEDBG4(CLNT, ERROR, "error %d receiving from umgr", rc);
    return 901;
  } else if (sb.tosuio()->resid () == 0) {
    FLUMEDBG3(CLNT, ERROR, "got nothing from umgr!");
    return 902;
  }

  /* parse the response */
  if (!rc_rxx.match (str(sb))) {
    warn ("str is [%s]\n", str(sb).cstr());
    return 903;
  }
  rc = atoi (rc_rxx[1]);
  if (rc != 0)
    return 904;

  static rxx x2 ("(\\d+)\\s+(\\S+)\n", "m");
  if (!x2.match (str(sb))) {
    warn ("str is [%s]\n", str(sb).cstr());
    return 905;
  }
  _uid = x2[2];

  fprintf (stderr, "Created new account for user %s, pw %s, uid %s\n", 
           un.cstr(), pw.cstr(), _uid.cstr());

  return 0;
}

static int _login (str un, str pw)
{
  strbuf sb;
  int rc;
   
  /* send request to user manager */
  sb.fmt ("login %s %s\n", un.cstr(), pw.cstr());
  if ((rc = sb.tosuio()->output (to_umgr)) < 0) {
    FLUMEDBG4(CLNT, ERROR, "error %d sending newuser request to umgr", rc);
    return 800;
  }
   
  /* get response from user manager */
  if ((rc = sb.tosuio()->input (from_umgr)) < 0) {
    FLUMEDBG4(CLNT, ERROR, "error %d receiving from umgr", rc);
    return 801;
  } else if (sb.tosuio()->resid () == 0) {
    FLUMEDBG3(CLNT, ERROR, "got nothing from umgr!");
    return 802;
  }

  /* parse the response */
  if (!rc_rxx.match (str(sb)))
    return 803;
  rc = atoi (rc_rxx[1]);
  if (rc != 0)
    return 804;

  static rxx resp_rxx ("(\\d+)( \\((\\S+),(\\S+),(\\S+)\\))?\n");
  if (!resp_rxx.match (str(sb))) {
    warn ("str is [%s]\n", str(sb).cstr());
    return 805;
  }
  _uid = resp_rxx[3];
  _gid = resp_rxx[4];
  _tpw = resp_rxx[5];
  
  fprintf (stderr, "logged in user %s pw %s uid %s gid %s tpw %s\n", 
           un.cstr(), pw.cstr(), _uid.cstr(), _gid.cstr(), _tpw.cstr());

  return 0;
}

int umgr_newuser (str umgr, str un, str pw, 
                  str &uid)
{
  int rc;

  if ((rc = _connect (umgr)))
    return rc;

  if ((rc = _newuser (un, pw)))
    return rc;

  uid = _uid;
  return _disconnect ();
}

int umgr_login (str umgr, str un, str pw, 
                str &uid, str &gid, str &tpw)
{
  int rc;
  if ((rc = _connect (umgr)))
    return rc;

  if ((rc = _login (un, pw)))
    return rc;

  uid = _uid;
  gid = _gid;
  tpw = _tpw;
  return _disconnect ();
}

int umgr_newuser_login (str umgr, str un, str pw,
                        str &uid, str &gid, str &tpw)
{
  int rc;
  if ((rc = _connect (umgr)))
    return rc;

  if ((rc = _newuser (un, pw)))
    return rc;

  if ((rc = _login (un, pw)))
    return rc;

  uid = _uid;
  gid = _gid;
  tpw = _tpw;
  return _disconnect ();
}

str uname_to_homedir_link (str umgr, str uname) {
  strbuf sb;
  sb.fmt ("/ihome/%s/dir/%c/%c/%c/%c/%s", umgr.cstr(), 
          uname[0], uname[1], uname[2], uname[3], uname.cstr());
  return str(sb);
}

str uname_to_homedir (str umgr, str uname) {
  str uid = name2uid (umgr, uname);
  return strbuf ().fmt ("/ihome/%s", uid.cstr ());
}

str uid_to_homedir (str uid) {
  return str (strbuf ("/ihome/%s/", uid.cstr()));
}

str uid_to_tags_filename (str uid) {
  return str (strbuf ("/ihome/%s/.flume/tags", uid.cstr()));
}

str uid_to_groups_filename (str uid) {
  return str (strbuf ("/ihome/%s/.flume/groups", uid.cstr()));
}

static bool
parsetags (const char *uid, principal_t *p, bool isgroup) {
  const str tagfile = str (strbuf ("/ihome/%s/.flume/tags", uid));
  parseargs pa (tagfile);
  bool errors = false;
  int line;
  vec<str> av;
  conftab ct;
  str etag, wtag, rtag, gtag, uetag, itag;
  
  ct.add ("ExportProtect", &etag)
    .add ("WriteProtect", &wtag)
    .add ("ReadProtect", &rtag)
    .add ("GroupHandle", &gtag)
    .add ("ExportProtectUmgr", &uetag)
    .ignore ("ReadProtectUmgr")
    .ignore ("GroupReadPrivileges")
    .ignore ("WriteProtectUmgr")
    .ignore ("GroupAllPrivileges");

  if (isgroup) {
    ct.ignore ("IntegrityProtect");
  } else {
    ct.add ("IntegrityProtect", &itag);
  }
  
  while (pa.getline (&av, &line)) {
    if (!ct.match (av, tagfile, line, &errors)) {
      errors = true;
    }
  }
  if (!errors) {
    errors |= handle_from_armor(etag.cstr(), &p->etag);
    errors |= handle_from_armor(wtag.cstr(), &p->wtag);
    errors |= handle_from_armor(rtag.cstr(), &p->rtag);
    errors |= handle_from_armor(gtag.cstr(), &p->gtag);
    errors |= handle_from_armor(uetag.cstr(), &p->uetag);
    if (isgroup)
      p->itag = 0;
    else 
      errors |= handle_from_armor(itag.cstr(), &p->itag);
  }
  
  return !errors;
}

static bool
read_group_tags (str uid, principal_hash_t *h) {
  /* Assumes that our S is big enough to read groups file
   * input looks like this: pQuJuB  9sqsaaaaaaaba..9wqsaaaaaaaba    92qsaaaaaaagg   a
   */
  str wholefile = file2str (uid_to_groups_filename (uid));
  if (!wholefile) {
    FLUMEDBG3 (CLNT, CHATTER, "could not read groups file\n");
    return true;
  }
  
  static rxx split_lines ("\\s*\n\\s*", "m");
  static rxx parse_line ("^\\s*(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S+)\\s*$");
  vec<str> lines;
  split (&lines, split_lines, wholefile);
  
  for(unsigned i=0; i<lines.size(); i++) {
    if (parse_line.match (lines[i])) {

      principal_t *p = New principal_t (parse_line[1]);
      if (!parsetags (parse_line[2], p, true)) {
        fprintf (stderr, "error parsing tags file for group %s\n", parse_line[1].cstr());
        return false;
      }
      h->insert (p);

    } else 
      fprintf (stderr, "error parsing groups line [%s]\n", lines[i].cstr());
  }
  return true;
}

principal_t *
read_user_tags (str un, str uid, principal_hash_t *h) {
  /* Read in a principal's "tags" and "groups" files */
  x_labelset_t *tags_ls = labelset_alloc ();
  bool ok;
  principal_t *p, *r = NULL;

  str tags_filename = uid_to_tags_filename (uid);
  if (flume_stat_file (tags_ls, tags_filename) < 0) {
    fprintf (stderr, "stat error for %s, errno %d\n", 
             tags_filename.cstr(), errno);
    goto done;
  }

  p = New principal_t (un);
  if (flume_set_label (&tags_ls->S, LABEL_S, 0) < 0) {
    fprintf (stderr, "Error setting label on tags files\n");
    goto done;
  }

  ok = parsetags (uid, p, false);
  if (!ok) {
    fprintf (stderr, "Error reading/parsing user's tags files\n");
    goto done;
  }
  
  if (h)
    h->insert (p);

  /* read groups */
  if (!read_group_tags (uid, h)) {
    fprintf (stderr, "Error reading/parsing user's groups\n");
    goto done;
  }

  if (clear_label (LABEL_S) < 0) {
    fprintf (stderr, "could not clear S label\n");
    goto done;
  }

  r = p;

 done:
  labelset_free(tags_ls);
  return r;
}

str
name2uid (str umgr, str uname) {
  if (!uname)
    return "";
  if (uname.len() < 6) {
    fprintf (stderr, "username is too short [%s]\n", uname.cstr());
    return NULL;
  }
  
  char buf[1024];
  str link = uname_to_homedir_link(umgr, uname);
  if (flume_readlink (link.cstr(), buf, 1024) < 0) {
    fprintf (stderr, "Could not read link at %s\n", link.cstr());
    return NULL;
  }

  static rxx x ("\\/ihome\\/(.*)$");
  if (x.match (str(buf)))
    return x[1];

  fprintf (stderr, "could not find uid from umgr link [%s]\n", buf);
  return NULL;
}

