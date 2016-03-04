
// -*-c++-*-

#include "async.h"
#include "crypt.h"
#include "arpc.h"
#include "fsutil.h"
#include "parseopt.h"
#include "iddutil.h"
#include <sys/types.h>
#include <errno.h>
#include "rxx.h"
#include "asyncutil.h"

static void 
usage (str loc)
{
  if (loc && loc.len () > 0)
    warnx << progname << ": " << loc << " ";
  warnx << "usage: <FS> \n" 
    "\t [-R|-P|-I|-l|-G|-o]\n"
    "\t-u <username>\n"
    "\t-g <groupname>\n" 
    "\t-a <attr-file>\n"
    "\t-n <num-aiods>\n"
    "\t-s <shmem-sze>\n"
    "\t-m <maxbuf-sze>\n"
    "\t-t <miss-cache-lifetime>\n"
    "\t-p <num-procs>\n"
    "\t-L <label>\n"
    "\t <jaildir> <mountpoint>\n";
}

//-----------------------------------------------------------------------

void
fs::cfg_t::init ()
{
  if (_public && !_ls) {
    _ls = New refcounted<labelset_t> (LABEL_S | LABEL_I);
  }
  if (_integrity_ns) {
    _root_ls = New refcounted<labelset_t> (LABEL_S | LABEL_I | LABEL_O);
    _root_ls->I ()->set_infinite ();
  }
}

//-----------------------------------------------------------------------

ptr<const labelset_t> fs::cfg_t::def_ls () { return _ls; }

//-----------------------------------------------------------------------

bool
fs::cfg_t::parseopts (int argc, char *const argv[], str loc)
{
  int id;
  int ch;
  bool rc = true;

  _prog = argv[0];

  getopt_reset ();
  
  while ((ch = getopt (argc, argv, "i:m:s:n:u:g:t:p:oRPIGL:S:")) != -1) {
    switch (ch) {
    case 'o':
      _optmz = true;
      break;
    case 'G':
      _ghetto_eas = true;
      break;
    case 'p':
      if (!convertint (optarg, &_n_proc)) {
	warn << loc << "cannot convert into integer: " << optarg << "\n";
	rc = false;
      }
      break;
    case 'u':
      if (_user) {
	warn << loc << "-u option specified more than once!\n";
	rc = false;
      } else if (convertint (optarg, &id)) {
	_user = New refcounted<flume_usr_t> (id);
      } else {
	_user = New refcounted<flume_usr_t> (optarg);
	if (!*_user) {
	  warn << loc << "cannot find user " << optarg << "\n";
	  rc = false;
	}
      }
      break;
    case 't': 
      if (_miss_cache_lifetime) {
	warn << loc << "-t option specified more than once!\n";
      } else if (!convertint (optarg, &_miss_cache_lifetime)) {
	warn << loc << "-t option expects an integery\n";
      }
      break;
    case 'L':
      _ls = New refcounted<labelset_t> ();
      if (!_ls->from_str (optarg)) {
	warn << loc << "cannot parse given labelset: " << optarg << "\n";
	rc = false;
      }
      break;
    case 'g':
      if (_group) {
	warn << loc << "-g option specified more than once!\n";
	rc = false;
      } else if (convertint (optarg, &id)) {
	_group = New refcounted<flume_grp_t> (id);
      } else {
	_group = New refcounted<flume_grp_t> (optarg);
	if (!*_group) {
	  warn << loc << "cannot find group " << optarg << "\n";
	  rc = false;
	}
      }
      break;
    case 'm':
      if (!convertint (optarg, &_maxbuf)) {
	warn << loc << "-m option takes an integer\n";
	rc = false;
      }
      break;
    case 's':
      if (!convertint (optarg, &_shmsize)) {
	warn << loc << "-s option takes an integer\n";
	rc = false;
      }
      break;
    case 'n':
      if (!convertint (optarg, &_n_aiods)) {
	warn << loc << "-n option takes an integer\n";
	rc = false;
      }
      break;
    case 'i':
      if (!_idd_cfg.from_str (optarg)) {
	warn << loc << "-i takes an encoded argument\n";
	rc = false;
      }
      break;
    case 'R':
      _readonly = true;
      break;
    case 'P':
      _public = true;
      break;
    case 'S':
      _handle_seed = optarg;
      break;
    case 'I':
      _integrity_ns = true;
      break;
    default:
      rc = false;
      break;
    }
  }

  argv += optind;
  argc -= optind;

  if (argc != 2) {
    rc = false;
  } else {
    _root = argv[0];
    _mountpoint = argv[1];
  }


  if (!rc)
    usage (loc);

  return rc;
}

//-----------------------------------------------------------------------

static void
add_ls (vec<str> *v, const char *o, ptr<const labelset_t> ls)
{
  if (ls) {
    strbuf b;
    str s = ls->to_str ();
    b << "'" << s << "'";
    add_opt (v, o, s);
  }
}

//-----------------------------------------------------------------------

bool
fs::cfg_t::to_argv (vec<str> *argv) const
{
  str err;
  if ((err = can_exec (_prog))) {
    warn << "FS execution error: " << err << "\n";
    return false;
  } else {
    argv->push_back (_prog);
    if (_public) add_flag (argv, "-P");
    if (_readonly) add_flag (argv, "-R");
    if (_integrity_ns) add_flag (argv, "-I");
    if (_ghetto_eas) add_flag (argv, "-G");
    if (_optmz) add_flag (argv, "-o");
    add_opt (argv, "-u", _user->getname ());
    add_opt (argv, "-g", _group->getname ());
    add_opt (argv, "-n", _n_aiods);
    add_opt (argv, "-m", _maxbuf);
    add_opt (argv, "-i", _idd_cfg.to_str ());
    add_opt (argv, "-t", _miss_cache_lifetime);
    add_opt (argv, "-p", _n_proc);
    if (_handle_seed)
      add_opt (argv, "-S", _handle_seed);
    add_ls (argv, "-L", _ls);
    argv->push_back (_root);
    argv->push_back (_mountpoint);
  }

  return true;
}

//-----------------------------------------------------------------------

str
fs::cfg_t::to_str () const
{
  strbuf b;
  b << " root=" << _root << "; mountpoint=" << _mountpoint 
    << "; n_proc=" << _n_proc;
  if (_public) b << " PUBLIC";
  if (_optmz) b << " OPTMZ";
  if (_readonly) b << " READONLY";
  if (_integrity_ns) b << " INTEGRITY-NS";
  if (_ghetto_eas) b << " GHETTO-EAs";
  if (_miss_cache_lifetime) b << " MissCacheLifetime=" << _miss_cache_lifetime;
  if (_ls) b << " DefaultLabels='" << _ls->to_str () << "'";
  return b;
}

str
fs::flatten (const vec<str> &in, bool abs, bool dir)
{
  strbuf b;
  if (abs) b << "/";
  bool first = true;
  for (size_t i = 0; i < in.size (); i++) {
    if (!first) b << "/";
    else first = false;
    b << in[i];
  }

  if (dir) 
    b << "/";

  return b;
}

//-----------------------------------------------------------------------

bool 
fs::path_split (vec<str> *out, str *np, const str &in)
{
  static rxx x ("/+");
  bool ret (true);
  if (in[0] != '/') 
    ret = false;

  // assert truths given by the leading slash
  assert (split (out, x, in) >= 1 || !ret);
  if (out->size () && (*out)[0].len () == 0) {
    assert (ret);
    out->pop_front ();
  }
  
  if (np) {
    *np = flatten (*out, true, false);
  }
  return ret;
}

//-----------------------------------------------------------------------

str
fs::combine_and_normalize (const str &cwd, const str &path, vec<str> *out)
{
  str combined;
  if (path[0] == '/') {
    combined = path;
  } else {
    strbuf b;
    if (cwd) 
      b << cwd;
    b << "/" << path;
    combined = b;
  }
  return dedotify (combined, out);
}

//-----------------------------------------------------------------------

template<class T>
void reverse (vec<T> *in)
{
  ssize_t p1, p2;
  p1 = 0;
  p2 = in->size () - 1;
  while (p1 < p2) {
    T tmp = (*in)[p1];
    (*in)[p1] = (*in)[p2];
    (*in)[p2] = tmp;
    p1 ++;
    p2 --;
  }
}

//-----------------------------------------------------------------------


// Remove all '.' and '..' path components from the input path.
str
fs::dedotify (const str &in, vec<str> *out)
{

  if (in.len () == 0)
    return ".";
  
  vec<str> v;

  vec<str> out_tmp;
  if (!out) out = &out_tmp;

  bool abs = false;
  if (path_split (&v, NULL, in))
    abs = true;

  int rm = 0;

  for (ssize_t i = v.size () - 1; i >= 0; i--) {
    if (v[i] == ".")
      continue;
    else if (v[i] == "..") 
      rm++;
    else if (rm == 0) {
      out->push_back (v[i]);
    } else {
      rm --;
    }
  }

  reverse (out);
  bool dir = (in[in.len () - 1] == '/');
  return flatten (*out, abs, dir);
}

//-----------------------------------------------------------------------

bool
fs::is_legal_filename (const str &s)
{
  for ( const char *cp = s.cstr (); *cp; cp++) {
    if (*cp == '/' || *cp == '\n' || *cp == '\r') 
      return false;
  }
  return true;
}

//-----------------------------------------------------------------------

bool
fs::in_same_dir (const vec<str> &p1, const vec<str> &p2)
{
  if (p1.size () != p2.size ())
    return false;

  for (size_t i = 0; i < p1.size () - 1; i++)
    if (p1[i] != p2[i])
      return false;

  return true;
}

//-----------------------------------------------------------------------

str
fs::paste (const str &m, const str &f_in)
{
  strbuf b;
  b << m;

  str f = f_in;
  if (!f) f = "";

  if (m[m.len () - 1] != '/') {
    if (f[0] == '/') {
      b << f;
    } else {
      b << "/" << f;
    }
  } else {
    if (f[0] == '/') {
      b << (f.cstr () + 1);
    } else {
      b << f;
    }
  }
  return b;
}

//-----------------------------------------------------------------------

void
fs::stat2xdr (const struct stat &sb, x_stat_t *out)
{
#define M(f) out->f = sb.st_##f

  memset(out, 0, sizeof (*out));

  M(dev);
  M(ino);
  M(mode);
  M(nlink);
  M(uid);
  M(gid);
  M(rdev);
  M(atime);
  M(mtime);
  M(ctime);
  M(size);
  M(blocks);
  M(blksize);

  // Not supported on linux....
  //M(flags);
  //M(gen);

#undef M

}

//-----------------------------------------------------------------------

str
fs::top_level_fix (const str &in)
{
  if (!in) return NULL;
  else if (in.len () == 0) return "/";
  else return in;
}

//-----------------------------------------------------------------------

bool
fs::is_root (const str &in)
{
  static rxx x ("/+");
  return in && x.match (in);
}

//-----------------------------------------------------------------------

bool
fs::cfg_t::has_minimum_label ()
{
  return (def_ls () && def_ls ()->is_minimum ());
}

//-----------------------------------------------------------------------

void
fs::xdr2timeval (const x_timeval_t &in, struct timeval *out)
{
  out->tv_sec = in.tv_sec;
  out->tv_usec = in.tv_usec;
}

//-----------------------------------------------------------------------

tamed void
fs::cfg_t::init_idd (cbb cb)
{
  tvars {
    bool rc;
  }
  twait { _idd_cfg.alloc_and_start (&_idd, mkevent (rc)); }
  init_ea_mgr ();
  cb->trigger (rc);
}

//-----------------------------------------------------------------------

void
fs::cfg_t::init_ea_mgr ()
{
  if (_ghetto_eas) { _ea_mgr = New refcounted<ghetto_ea_mgr_t> (idd ()); }
  else { _ea_mgr = New refcounted<real_ea_mgr_t> (); }
}

//-----------------------------------------------------------------------

void
fs::cfg_t::set_idd (const idd::server_handle_t *i)
{
  _idd_cfg = i->cfg ();
  if (_idd) 
    delete _idd;
  _idd = _idd_cfg.alloc ();
}

//-----------------------------------------------------------------------

tamed void
fs::cfg_t::simple_init (bool ghetto, const str &idds, cbb cb)
{
  tvars {
    bool rc (true);
  }
  
  if (ghetto && !idds) {
    warn << "When using ghetto EAs, need an IDD with -I !\n";
    rc = false;
  } else {
    _ghetto_eas = ghetto;
    if (ghetto) {
      if (!_idd_cfg.from_str_simple (idds)) {
	warn << "Cannot parse IDD specification: " << idds << "\n";
	rc = false;
      } else {
	twait { init_idd (mkevent (rc)); }
	if (!rc) {
	  warn << _idd_cfg.debug_str () << ": connection to IDD failed!\n";
	}
      }
    } else {
      init_ea_mgr ();
    }
  }
  cb->trigger (rc);
}
