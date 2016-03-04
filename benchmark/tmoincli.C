#include "tmoincli.h"

int global_counter = 0;

str tmoin_cli::userlist;
str tmoin_cli::path;
vec<tmoinuser_t> tmoin_cli::users;
int tmoin_cli::suffix_range;
bool tmoin_cli::write_benchmark = false;
bool tmoin_cli::sequential_users = false;
bool tmoin_cli::sequential_read = false;
int tmoin_cli::initial_rev = 1;
int tmoin_cli::write_size = 32;
vec<int> tmoin_cli::current_revs;

tmoin_cli::tmoin_cli (int dummy) : base_cli (dummy) {
  page_suffix = -1;
  counter = global_counter++;
}

tmoin_cli::~tmoin_cli () { }

base_cli*
tmoin_cli::clone () {
  tmoin_cli *c = New tmoin_cli ();
  c->clone_base (this);
  return c;
}

str
tmoin_cli::make_cookie () {
  int user_idx;
  strbuf cookie;

  if (!userlist)
    return str("");

  if (sequential_users) {
    user_idx = counter % users.size ();
  } else {
    user_idx = random () % users.size ();
  }

  cookie.fmt ("Cookie: TRAZ_UN=%s; TRAZ_UID=%s; TRAZ_GID=%s; TRAZ_TPW=%s\r\n",
              users[user_idx].uname, users[user_idx].uid, 
              users[user_idx].gid, users[user_idx].tpw);
  return str(cookie);
}

str
tmoin_cli::make_path () {
  strbuf p;
  p << "/" << path;
  if (suffix_range > 0) {
    if (sequential_read) {
      page_suffix = counter % suffix_range;
    } else {
      do {
        // Just repeat until we pick a page that's not locked
        page_suffix = random () % suffix_range;
      } while (current_revs[page_suffix] == LOCKED);
    }
    p << page_suffix;

    if (write_benchmark) {
      // Lock this page so no other clients will try to edit it.
      assert (current_revs[page_suffix] != LOCKED);
      page_revision = current_revs[page_suffix];
      current_revs[page_suffix] = LOCKED;
    }
  }
  return str(p);
}

str
tmoin_cli::make_random_text () {
  strbuf sb;
  char s[2];
  s[1] = 0;

  for (int i=0; i<write_size; i++) {
    s[0] = (char) ((random () % ('z'-'a')) + 'a');
    sb << s;
  }
  return str (sb);
}

str
tmoin_cli::make_const_text () {
  strbuf sb;

  for (int i=0; i<write_size; i++) {
    sb << "A";
  }
  return str (sb);
}

str
tmoin_cli::write_req () {
  /* Expected POST arguments:
   *  button_save [u'Save Changes']
   *  rev [u'9']
   *  editor [u'text']
   *  action [u'edit']
   *  savetext [u'Stuff on the page\r\n']
   */

  strbuf sb, args;
  str p = make_path ();
  assert (page_suffix >= 0);

  args.fmt ("action=edit&button_save=Save+Changes&rev=%d&editor=text&savetext=%s-rev%d",
            page_revision, make_const_text ().cstr(), page_revision);

  sb << "POST " << p << " HTTP/1.0\r\n"
     << "User-agent: ASCLI - Reaming Web Servers Since 2004\r\n"
     << "Content-Type: application/x-www-form-urlencoded\r\n"
     << "Content-Length: " << args.tosuio ()->resid () << "\r\n"
     << make_cookie ()
     << "Connection: close\r\n\r\n"
     << args;
  return str(sb);
}

str
tmoin_cli::read_req () {
  strbuf sb;
  sb << "GET " << make_path () << " HTTP/1.0\r\n"
     << "User-agent: ASCLI - Reaming Web Servers Since 2004\r\n"
     << make_cookie ()
     << "Connection: close\r\n\r\n";
  return str(sb);
}

str
tmoin_cli::get_req () {
  if (write_benchmark)
    return write_req ();
  else
    return read_req ();
}

int
tmoin_cli::parse_resp (str resp) {

  if (write_benchmark) {
    if (!strstr(resp.cstr(), "Thank you for your changes")) {
      if (noisy) {
        fprintf (ERR, "Bad reponse is:\n");
        fprintf (ERR, "%s\n", resp.cstr ());
      }
      return -1;
    }

    if (write_benchmark) {
      // unlock the page and increase the revision number
      assert (current_revs[page_suffix] == LOCKED);
      current_revs[page_suffix] = page_revision + 1;
    }

  } else {
    if (!strstr(resp.cstr(), make_const_text ())) {
      if (noisy) {
        fprintf (ERR, "Bad reponse is:\n");
        fprintf (ERR, "%s\n", resp.cstr ());
      }
      return -1;
    }
  }

  return 0;
}

void
tmoin_cli::read_userlist (str path)
{
  int rc, i=1;
  FILE *f;
  tmoinuser_t u;

  if (!(f = fopen (path.cstr(), "r")))
    fatal << "could not open userlist " << path << "\n";

  while ((rc = fscanf (f, "%s %s %s %s %s\n", u.uname, u.pw, u.uid, u.gid, u.tpw)) > 0) {
    if (rc != 5) 
      fatal ("malformed entry in userlist, line %d, matched %d\n", i, rc);

    if (noisy) fprintf (ERR, "gid %s tpw %s\n", u.gid, u.tpw);
    users.push_back (u);
    i++;
  }
  if (noisy) fprintf (ERR, "read %d login pairs from userlist\n", users.size());
  nusers = users.size ();
  fclose (f);
}

str
tmoin_cli::cmd_name () {
  return "tmoincli";
}

str
tmoin_cli::usage (str progname) {
  strbuf sb;
  sb << "usage: " << progname << " <common_args> " 
     << cmd_name () << " -H<f> -x<f> [-wsu] <host:port>\n"
     << "     -H<f>: read user logins / TPWs from file <f>\n"
     << "     -p<p>: Use path <p>, ie: http://server:port/<p>\n"
     << "     -r<n>: Append a numerical suffix to <path>.  Rotate within [0:n)\n"
     << "     -w   : Benchmark writing pages\n"
     << "     -s   : Rotate through suffixes in sequential order (default random)\n"
     << "     -v<n>: Start edits at revision <v>\n"
     << "     -u   : Rotate through users in sequential order (default random)\n"
     << "     -b<n>: Write <n> bytes when writing a page (default 1kbyte)\n";

  return str(sb);
}

int
tmoin_cli::parse_args (int argc, char *argv[]) {
  extern int nconcur;

  int ch;
  while ((ch = getopt (argc, argv, "H:p:r:wsuv:b:")) != -1) {
    switch (ch) {
    case 'H':
      userlist = optarg;
      break;
    case 'p':
      path = optarg;
      break;
    case 'r':
      suffix_range = atoi (optarg);
      break;
    case 'w':
      write_benchmark = true;
      break;
    case 's':
      sequential_read = true;
      break;
    case 'u':
      sequential_users = true;
      break;
    case 'v':
      initial_rev = atoi (optarg);
      break;
    case 'b':
      write_size = atoi (optarg);
      break;
    default:
      return -1;
    }
  }

  if (!path) {
    warnx << "You must specify -p path flag\n";
    return -1;
  } else if (sequential_read && (suffix_range < 1)) {
    warnx << "-s makes no sense without -r\n";
    return -1;
  } else if (initial_rev > 1 && !write_benchmark) {
    warnx << "-v makes no sense without -w\n";
    return -1;
  } else if (write_benchmark && (nconcur > suffix_range)) {
    warnx ("Not enough pages (%d) for the concurrency level (%d)\n", 
           suffix_range, nconcur);
    return -1;
  }

  if (userlist)
    read_userlist (userlist);

  current_revs.setsize (suffix_range);
  for (int i=0; i<current_revs.size(); i++) {
    current_revs[i] = initial_rev;
  }

  return optind;
}
