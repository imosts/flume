#include "parseopt.h"
#include "trazcart.h"
#include <unistd.h>

/* These variables are shared between all client threads */
static str userlist;
static str executable;
static str path;
static vec<user_t> users;
static int counter;


trazcart_cli::trazcart_cli (int dummy) : base_cli (dummy) {
  tried_cookie = false;
  user_idx = counter++;
}

base_cli*
trazcart_cli::clone () {
  trazcart_cli *c = New trazcart_cli ();
  c->clone_base (this);
  return c;
}

str
trazcart_cli::get_req () {
  strbuf sb, get_path, args, cookie;

  get_path << "/" << path;

  user_idx %= users.size();
  args.fmt ("?UN=%s&PW=%s", users[user_idx].h, users[user_idx].token_str);
  args.fmt ("&EXEC=%s", executable.cstr());
  args.fmt ("&Submit=Submit");
  args.fmt ("&subtotal=%d&desc=Product+Number+%d&submit=submit", 
            (int) (random () % 1000), (int) (random () % INT_MAX));

  if (users[user_idx].cart_id >= 0)
    cookie << "Cookie: CART_ID=" << users[user_idx].cart_id << "\r\n";
  
  sb << "GET " << str (get_path) << str (args) << " HTTP/1.0\r\n"
     << "User-agent: ASCLI - Reaming Web Servers Since 2004\r\n"
     << str (cookie)
     << "Connection: close\r\n\r\n";
  return str(sb);
}

static char *cookie_prefix ("Set-Cookie: CART_ID=");

int 
trazcart_cli::parse_cookie (str s) {
  char buf[32];
  bzero (buf, 32);
  const char *p, *e;
  int ret;

  if (!(p = strstr (s.cstr(), cookie_prefix))) {
    warn << "err1\n";
    return -1;
  }
  p += strlen (cookie_prefix);

  if (!(e = strchr (p, ';'))) {
    warn << "err2\n";
    return -1;
  }
  memcpy (buf, p, e-p);
  if (!convertint (buf, &ret)) {
    warn << "err3 " << buf << "\n";
    return -1;
  }
  return ret;
}

int
trazcart_cli::parse_resp (str resp) {

  if (!strstr (resp.cstr (), "\r\n\r\n"))
    return -1;

  if ((users[user_idx].cart_id = parse_cookie (resp)) < 0)
    fatal << "Could not find CART_ID cookie in response: " << resp << "\n";
  if (noisy) 
    fprintf (ERR, "User %d has CART_ID %d\n", user_idx, users[user_idx].cart_id);
  return 0;
}

void
trazcart_cli::read_userlist (str path)
{
  int rc, i=1;
  FILE *f;
  user_t u;

  if (!(f = fopen (path.cstr(), "r")))
    fatal << "could not open userlist " << path << "\n";

  while ((rc = fscanf (f, "%s %s\n", u.h, u.token_str)) > 0) {
    if (rc != 2) 
      fatal << "malformed entry in userlist, line " << i << "\n";

    if (noisy) fprintf (ERR, "un %s pw %s\n", u.h, u.token_str);
    u.cart_id = -1;
    users.push_back (u);
    i++;
  }
  if (noisy) fprintf (ERR, "read %d login pairs from userlist\n", users.size());
  nusers = users.size ();
  fclose (f);
}

str
trazcart_cli::cmd_name () {
  return "trazcart";
}

str
trazcart_cli::usage (str progname) {
  strbuf sb;
  sb << "usage: " << progname << " <common_args> " 
     << cmd_name () << " -H<f> -x<f> <host:port>\n"
     << "     -H<f>: read user logins from file <f>\n"
     << "     -x<f>: Use Traz executable <f>\n"
     << "     -p<p>: Use path <p>, ie: http://server:port/<p>\n";
  return str(sb);
}

int
trazcart_cli::parse_args (int argc, char *argv[]) {
  int ch;
  while ((ch = getopt (argc, argv, "H:x:p:r:")) != -1) {
    switch (ch) {
    case 'H':
      userlist = optarg;
      break;
    case 'x':
      executable = optarg;
      break;
    case 'p':
      path = optarg;
      break;
    default:
      return -1;
    }
  }

  if (!userlist || !executable || !path) {
    warnx << "You must specify -H -x and -p flags\n";
    return -1;
  }
  
  read_userlist (userlist);
  return optind;
}

