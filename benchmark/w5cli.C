#include "w5cli.h"

int w5_counter = 0;

str w5_cli::which_page = 0;
int w5_cli::use_nusers = 0;

str w5_cli::userlist;
vec<w5user_t> w5_cli::users;
bool w5_cli::write_benchmark = false;

w5_cli::w5_cli (int dummy) : base_cli (dummy) {
  if (!dummy) {
    counter = w5_counter++;

    if (0) {
      myuser = users[counter % use_nusers];
    } else {
      int user_idx = random () % users.size ();
      myuser = users[user_idx];
    }
  }
}

w5_cli::~w5_cli () { }

base_cli*
w5_cli::clone () {
  w5_cli *c = New w5_cli ();
  c->clone_base (this);
  return c;
}

str
w5_cli::make_cookie () {
  strbuf cookie;

  if (strcmp (which_page, W5CLI_LOGINPAGE))
    cookie.fmt ("Cookie: FLUME_UN=%s; FLUME_GID=%s; FLUME_TPW=%s\r\n", 
                myuser.un, myuser.gid, myuser.tpw);

  return str(cookie);
}

str
w5_cli::make_path () {
  strbuf sb;
  sb << "http://" << make_http_host ();

  if (!strcmp (which_page, W5CLI_LOGINPAGE)) {
    sb << "/trusted"; 
  } else if (!strcmp (which_page, W5CLI_HOMEPAGE)) {
    sb << "/trusted";
  } else if (!strcmp (which_page, W5CLI_ALBUM)) {
    sb << myuser.base_url_exec << myuser.album_extension;
  } else if (!strcmp (which_page, W5CLI_BLOG)) {
    sb << myuser.base_url_exec << "/blog/rundjango/";
  } else if (!strcmp (which_page, W5CLI_DEBUG)) {
    sb << "/debug";
  } else if (!strcmp (which_page, W5CLI_FASTCGITEST)) {
    sb << "/fastcgi-test";
  } else if (!strcmp (which_page, W5CLI_NULLPY)) {
    sb << myuser.base_url_exec << "/nullcgipy/nullcgi";
    //sb << myuser.base_url_py << "/nullcgipy/nullcgi.py";
  } else if (!strcmp (which_page, W5CLI_NULLC)) {
    sb << myuser.base_url_exec << "/nullcgic/nullcgi";
  } else if (!strcmp (which_page, W5CLI_APACHENULLC)) {
    sb << "/cgi-bin/nullcgi.cgi";
  } else if (!strcmp (which_page, W5CLI_DJANGONULL)) {
    sb << "/mysite/";
  } else if (!strcmp (which_page, W5CLI_DJANGOALBUM)) {
    sb << myuser.album_extension;
  } else {
    assert (0); // WTF?
  }
  return str (sb);
}

str
w5_cli::make_http_host () {
  strbuf sb;

  if (!strcmp (which_page, W5CLI_LOGINPAGE) || 
      !strcmp (which_page, W5CLI_HOMEPAGE) || 
      !strcmp (which_page, W5CLI_DEBUG) ||
      !strcmp (which_page, W5CLI_FASTCGITEST) ||
      !strcmp (which_page, W5CLI_APACHENULLC) ||
      !strcmp (which_page, W5CLI_DJANGONULL) ||
      !strcmp (which_page, W5CLI_DJANGOALBUM)) {
    sb << myuser.http_host;
  } else {
    sb << myuser.cid << "." << myuser.http_host;
  }
  return str (sb);
}

str
w5_cli::write_req () {
  /* Expected POST arguments:
   *  button_save [u'Save Changes']
   *  rev [u'9']
   *  editor [u'text']
   *  action [u'edit']
   *  savetext [u'Stuff on the page\r\n']
   */

  strbuf sb;
  str p = make_path ();

  sb << "POST " << p << " HTTP/1.0\r\n"
     << "Host: " << make_http_host () << "\r\n"
     << "User-agent: ASCLI - Reaming Web Servers Since 2004\r\n"
     << "Content-Type: application/x-www-form-urlencoded\r\n"
     << make_cookie ()
     << "Connection: close\r\n\r\n";
  return str(sb);
}

str
w5_cli::read_req () {
  strbuf sb;
  sb << "GET " << make_path () << " HTTP/1.0\r\n"
     << "Host: " << make_http_host () << "\r\n"
     << "Referer: http://hydra.lcs.mit.edu:8001/trusted\r\n"
     << "User-agent: ASCLI - Reaming Web Servers Since 2004\r\n"
     << make_cookie ()
     << "Connection: close\r\n\r\n";

  return str(sb);
}

str
w5_cli::get_req () {
  if (write_benchmark)
    return write_req ();
  else
    return read_req ();
}

int
w5_cli::parse_resp (str resp) {
  if (write_benchmark) {

  } else {
    str valid_match;


    if (!strcmp (which_page, W5CLI_LOGINPAGE)) {
      valid_match = "Create a new user";
    } else if (!strcmp (which_page, W5CLI_HOMEPAGE)) {
      valid_match = "Control Panel";
    } else if (!strcmp (which_page, W5CLI_ALBUM)) {
      valid_match = "I'm javascript";
    } else if (!strcmp (which_page, W5CLI_BLOG)) {
      valid_match = "W5 Blogger";
    } else if (!strcmp (which_page, W5CLI_DEBUG)) {
      valid_match = "W5 Debug info";
    } else if (!strcmp (which_page, W5CLI_FASTCGITEST)) {
      valid_match = "FastCGI in Flume";
    } else if (!strcmp (which_page, W5CLI_NULLPY)) {
      valid_match = "nullcgi.py!";
    } else if (!strcmp (which_page, W5CLI_NULLC)) {
      valid_match = "nullcgi!";
    } else if (!strcmp (which_page, W5CLI_APACHENULLC)) {
      valid_match = "nullcgi!";
    } else if (!strcmp (which_page, W5CLI_DJANGONULL)) {
      valid_match = "Hello, world";
    } else if (!strcmp (which_page, W5CLI_DJANGOALBUM)) {
      valid_match = "I'm javascript";
    } else {
      assert (0); // WTF?
    }

    if (!strstr (resp.cstr (), valid_match.cstr ())) {
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
w5_cli::read_userlist (str path)
{
  int rc, i=1;
  FILE *f;
  w5user_t u;

  if (!strcmp (path.cstr (), "-")) {
    f = stdin;
  } else if (!(f = fopen (path.cstr(), "r")))
    fatal << "could not open userlist " << path << "\n";

  while ((rc = fscanf (f, "%s %s %s %s %s %s %s %s\n", 
                       u.un, u.gid, u.tpw, u.cid, u.http_host, 
                       u.base_url_exec, u.base_url_py, u.album_extension)) > 0) {

    if (rc != 8) 
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
w5_cli::cmd_name () {
  return "w5cli";
}

str
w5_cli::usage (str progname) {
  strbuf sb;
  sb << "usage: " << progname << " <common_args> " 
     << cmd_name () << " -u<f> -n<n> -p<page> \n"
     << "     -u<f>    : read user logins / cookies from file <f>\n"
     << "     -n<n>    : use the first <n> users from the userlist\n"
     << "     -p<page> : request <page> from W5.  <page> can be loginpage, homepage, blog, or album\n";
  return str(sb);
}

int
w5_cli::parse_args (int argc, char *argv[]) {
  int ch;
  which_page = W5CLI_LOGINPAGE;

  while ((ch = getopt (argc, argv, "u:n:p:")) != -1) {
    switch (ch) {
    case 'u':
      userlist = optarg;
      break;
    case 'n':
      use_nusers = atoi (optarg);
      break;
    case 'p':
      which_page = optarg;
      break;
    default:
      return -1;
    }
  }

  if (userlist)
    read_userlist (userlist);
  else {
    warnx ("You must supply a userlist with -H\n");
    return -1;
  }

  if (use_nusers > users.size ()) {
    warnx ("Too many users(%d) for userlist(%d)\n", use_nusers, users.size ());
    return -1;
  }
  
  if (strcmp (which_page, W5CLI_LOGINPAGE) &&
      strcmp (which_page, W5CLI_HOMEPAGE) &&
      strcmp (which_page, W5CLI_BLOG) &&
      strcmp (which_page, W5CLI_ALBUM) &&
      strcmp (which_page, W5CLI_DEBUG) &&
      strcmp (which_page, W5CLI_FASTCGITEST) &&
      strcmp (which_page, W5CLI_NULLPY) &&
      strcmp (which_page, W5CLI_NULLC) &&
      strcmp (which_page, W5CLI_APACHENULLC) &&
      strcmp (which_page, W5CLI_DJANGONULL) &&
      strcmp (which_page, W5CLI_DJANGOALBUM)) {
    warnx ("Invalid argument to -u '%s'\n", which_page.cstr ()); 
    return -1;
  }

  return optind;
}
