
#include "flume.h"
#include "unixutil.h"
#include "rxx.h"
#include <grp.h>
#include <fcntl.h>
#include "parseopt.h"
#include <getopt.h>

extern int optind;

int
uname2uid (const str &n)
{
  struct passwd *pw;
  int ret = -1;
  if ((pw = getpwnam (n))) {
    ret = pw->pw_uid;
  }
  endpwent ();
  return ret;
}

str
uid2uname (int i)
{
  struct passwd *pw;
  str ret;
  if ((pw = getpwuid (i))) 
    ret = pw->pw_name;
  endpwent ();
  return ret;
}

void
got_dir (str *out, vec<str> s, str loc, bool *errp)
{
  strip_comments (&s);
  if (s.size () != 2) {
    warn << loc << ": usage: " << s[0] << " <path>\n";
    *errp = true;
    return;
  }
  if (!is_safe (s[1])) {
    warn << loc << ": directory (" << s[1] 
	 << ") contains unsafe substrings\n";
    *errp = true;
    return;
  }
  *out = dir_standardize (s[1]);
}

int
gname2gid (const str &g)
{
  struct group *gr;
  int ret = -1;
  if ((gr = getgrnam (g))) {
    ret = gr->gr_gid;
  }
  endgrent ();
  return ret;
}

bool
isdir (const str &d)
{
  struct stat sb;
  return (!stat (d, &sb) && (sb.st_mode & S_IFDIR) && !access (d, X_OK|R_OK));
}


bool
jailable_t::chroot ()
{
  if (FLUMEDBG2 (JAIL)) {
    str s = _jaildir;
    if (!s) s = "<NULL>";
    warn << "Calling chroot('" <<  s << "') with uid=" << _uid << "\n";
  }
  if (_jaildir && !_uid && isdir (_jaildir)) {
    if (::chroot (_jaildir.cstr ()) != 0)
      return false;
    if (FLUMEDBG2 (JAIL)) {
      warn << "Chrooted to: " << _jaildir << "\n";
    }
    _jailed = true;
    return true;
  }
  return true;
}

str
jailable_t::jail2real (const str &exe, bool force) const
{
  // if we're jailed, the we don't really want to have the option
  // of seeing the actual directory, relative to the real root;
  // but, we can fake getting the directory relative to the jail
  // if we give the 'force' flag
  
  str ret;
  if (force || _jailed) {
    if (exe[0] == '/')
      ret = exe;
    else {
      strbuf b ("/");
      b << exe;
      ret = b;
    }
  } else {
    if (!_jaildir) return exe;
    strbuf b (_jaildir);
    if (exe[0] != '/') b << "/";
    b << exe;
    ret = b;
  }

  if (FLUMEDBG2 (JAIL)) {
    strbuf b;
    b << "jail2real (" << exe << ", " << (force ? "True" : "False")
      << ") -> " << ret << "\n";
    flumedbg_warn (CHATTER, b);
  }
  return ret;
}

str 
jailable_t::nest_jails (const str &path) const
{
  if (!path)
    return _jaildir;
  else if (_jailed)
    return path;
  else {
    strbuf b (_jaildir);
    if (path[0] != '/') b << "/";
    b << path;
    return b;
  }
}

bool
dir_security_check (const str &dir)
{
  const char *p = dir.cstr ();
  while (*p == '/') { p++; }
  if (strcmp (p, ".") == 0 || strcmp (p, "..") == 0)
    return false;
  return true;
}

bool
jailable_t::jail_mkdir (const str &d, mode_t mode, flume_usr_t *u, flume_grp_t *g)
{
  if (_uid) {
    warn << "can't call run jail_mkdir unless root\n";
    return false;
  }
  assert (d);
  
  if (!dir_security_check (d)) {
    warn << d << ": directory contains forbidden directory references\n";
    return false;
  }

  // pass false; we haven't chrooted yet
  str dir = jail2real (d);
  struct stat sb;
  if (stat (dir.cstr (), &sb) != 0) {
    if (mkdir (dir.cstr (), mode != 0)) {
      warn ("%s: make directory failed: %m\n", dir.cstr ());
      return false;
    } 
    if (stat (dir.cstr (), &sb) != 0) {
      warn << dir 
	   << ": could not STAT directory even though mkdir succeeded.\n";
      return false;
    }
    warn << "made jail directory: " << dir << "\n";
  }
  if (!S_ISDIR (sb.st_mode)) {
    warn << dir << ": file exists and is not a directory\n";
    return false;
  }
  if (!fix_stat (dir, mode, u, g, sb)) {
    warn << dir << ": could not fix up permissions and ownership\n";
    return false;
  }
  return true;
}

static rxx slash ("/+");
bool
jailable_t::jail_mkdir_p (const str &d, mode_t mode, flume_usr_t *u, flume_grp_t *g)
{
  vec<str> subdirs;
  int rc;
  if ((rc = split (&subdirs, slash, d, 32)) <= 0) {
    warn << d << ": malformed directory\n";
    return false;
  }
  strbuf b;
  if (d[0] == '/')
    b << "/";
  for (u_int i = 0; i < subdirs.size (); i++) {
    if (subdirs[i].len ()) {
      b << subdirs[i];
      if (!jail_mkdir (str (b), mode, u, g)) 
	return false;
      b << "/";
    }
  }
  return true;
}

bool
jailable_t::fix_stat (const str &d, mode_t mode, flume_usr_t *u, flume_grp_t *g,
		      const struct stat &sb)
{
  if (_uid)
    return false;

  int newgid, newuid;
  bool chownit = false;

  newgid = sb.st_gid;
  newuid = sb.st_uid;

  // do not allow setuid/setgid directories or files
  mode = (mode & 0777);

  if ((sb.st_mode & 0777) != mode) {
    if (chmod (d.cstr (), mode) != 0) {
      warn ("%s: chmod failed: %m\n", d.cstr ());
      return false;
    }
  }

  if (u) {
    if (!*u) {
      warn ("%s: no such user!\n", u->getname ().cstr ());
      return false;
    }
    else if (u->getid () != newuid) {
      newuid = u->getid ();
      chownit = true;
    }
  }
 
  if (g) {
    if (!*g) {
      warn ("%s: no such group!\n", g->getname ().cstr ());
      return false;
    } else if (g->getid () != newgid) {
      newgid = g->getid ();
      chownit = true;
    }
  }

  if (chownit) {
    if (chown (d, newuid, newgid) != 0) {
      warn ("%s: cannot chown: %m\n", d.cstr ());
      return false;
    }
  }

  return true;
}

#define JAIL_CP_BUFSIZE 1024

bool
flume_cp (const str &src, const str &dest, int mode)
{
  bool ret = true;
  char buf[JAIL_CP_BUFSIZE];
  int infd = open (src.cstr (), O_RDONLY);
  if (infd < 0) {
    warn ("%s: cannot access file: %m\n", src.cstr ());
    return false;
  }
  int outfd = open (dest.cstr (), O_CREAT | O_TRUNC | O_WRONLY, mode);
  if (outfd < 0) {
    warn ("%s: cannot copy to file: %m\n", dest.cstr ());
    close (infd);
    return false;
  }

  int rc = 0, rc2 = 0;
  while (ret && (rc = read (infd, buf, JAIL_CP_BUFSIZE)) > 0) {
    if ((rc2 = write (outfd, buf, rc)) < 0) {
      warn ("%s: bad write: %m\n", dest.cstr ());
      ret = false;
    } else if (rc2 < rc) {
      warn ("%s: short write: %m\n", dest.cstr ());
      ret = false;
    }
  }
  if (rc < 0) {
    warn ("%s: read error: %m\n", src.cstr ());
    ret = false;
  }

  close (outfd);
  close (infd);
  if (!ret) {
    unlink (dest.cstr ());
  }
  return ret;
}

bool
jailable_t::jail_cp (const str &fn, mode_t mode, flume_usr_t *u, flume_grp_t *g)
{
  if (!will_jail ())
    return true;

  struct stat sb;

  // false argument --> we haven't chrooted yet.
  str dest = jail2real (fn);
  if (fn == dest) {
    warn << "refusing to copy file to itself: " << dest << "\n";
    return false;
  }
  if (!flume_cp (fn, dest, mode))
    return false;

  if (will_jail ()) {
    if (stat (dest.cstr (), &sb) != 0) {
      warn ("%s: cannot access newly copied file\n", dest.cstr ());
      return false;
    }
    if (!fix_stat (dest, mode, u, g, sb))
      return false;
  }
  return true;
}

str
apply_container_dir (const str &d, const str &f)
{
  if (f[0] == '/' || !d)
    return re_fslash (f.cstr ());
  else 
    return (strbuf (d) << "/" << f);
}

str 
re_fslash (const char *cp)
{
  while (*cp == '/' && *cp) cp++;
  return strbuf ("/") << cp;
}


str 
dir_standardize (const str &s)
{
  const char *bp = s.cstr ();
  const char *ep = bp + s.len () - 1;
  for ( ; bp <= ep && *ep == '/'; ep--) ;
  ep++;
  return str (bp, ep - bp);
}

static rxx safe_rxx ("(/\\.|\\./)");

bool
is_safe (const str &d)
{
  if (!d || d[0] == '.' || d[d.len () - 1] == '.' || safe_rxx.search (d))
    return false;
  return true;;
}

str
can_exec (const str &p)
{
  if (access (p.cstr (), R_OK)) 
    return ("cannot read executable");
  else if (access (p.cstr (), X_OK)) 
    return ("cannot execute");
  return NULL;
}

bool
can_read (const str &f)
{
  struct stat sb;
  return  (f && stat(f.cstr (), &sb) == 0 && S_ISREG (sb.st_mode)
	   && access (f.cstr(), R_OK) == 0);
}


int
myopen (const char *arg, u_int mode)
{
  struct stat sb;
  if (stat (arg, &sb) == 0)
    if (!S_ISREG (sb.st_mode)) 
      fatal << arg << ": file exists but is not a regular file\n";
    else if (unlink (arg) < 0 || stat (arg, &sb) == 0)
      fatal << arg << ": could not remove file\n";
 
  int fd = open (arg, O_CREAT|O_WRONLY, mode);
  if (!fd)
    fatal << arg << ": could not open file for writing\n";
  return fd;
}

void
strip_comments (vec<str> *in)
{
  ssize_t start_from = -1;
  ssize_t lim = in->size ();
  for (ssize_t i = 0; i < lim; i++) {
    const char *cp = (*in)[i].cstr ();
    const char *pp = strchr (cp, '#');
    if (pp) {
      if (pp == cp) {
	start_from = i;
      } else {
	(*in)[i] = str (cp, pp - cp);
	start_from = i + 1;
      }
      break;
    }
  }
  while ( start_from >= 0 && start_from < ssize_t (in->size ()) )
    in->pop_back ();
}

argv_t::argv_t ()
{
  _v.push_back (NULL);
}

argv_t::argv_t (const vec<str> &in, const char *const *seed)
{
  init (in, seed);
}

void
argv_t::init (const vec<str> &in, const char *const *seed)
{
  if (_v.size ())
    _v.clear ();

  if (seed)
    for (const char *const *s = seed; *s; s++) 
      _v.push_back (*s);

  for (u_int i = 0; i < in.size (); i++) {
    size_t len = in[i].len () + 1;
    char *n = New char[len];
    memcpy (n, in[i].cstr (), len);
    _free_me.push_back (n);
    _v.push_back (n);
  }
  _v.push_back (NULL);
}

argv_t::~argv_t ()
{
  const char *tmp;
  while (_free_me.size () && (tmp = _free_me.pop_front ()))
    delete [] tmp;
}

bool
ready_socket (const str &s)
{
  struct stat sb;
  if (stat (s.cstr (), &sb) < 0) {
    return true;
  } else if (S_ISSOCK(sb.st_mode)) {
    unlink (s.cstr ());
    return true;
  } else {
    return false;
  }
}

bool
flags_for_write (int i)
{
  return (i & ( O_WRONLY | O_RDWR | O_APPEND | O_CREAT | O_TRUNC) );
}

bool
flags_for_read (int i)
{
  // Note that on Linux and FreeBSD, the R/W flags to open aren't
  // the regular bit-set operators one would expect; hence the
  // operations below:
  int o = (i & O_ACCMODE);
  return (o == O_RDONLY || o == O_RDWR);
}

bool
flags_mutates (int i)
{
  return i & O_TRUNC;
}

int
flags_make_non_mutate (int i)
{
  return i & ~O_TRUNC;
}

int
my_socketpair (int *fds)
{
  return socketpair (AF_UNIX, SOCK_STREAM, 0, fds);
}

void
getopt_reset()
{

#ifdef __linux__
  optind = 0;
#else
  optind = 1;
#endif

}

#define TZPID32_BIT (1 << 30)

pid_t
flmpid_to_flmpid32 (u_int64_t x)
{
  return ((x & 0x3fffffff) | TZPID32_BIT);
}

bool
is_flmpid32 (pid_t p)
{
  return (p & TZPID32_BIT);
}
