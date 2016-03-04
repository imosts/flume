
#include "flume_cfg.h"
#include "sha1.h"

bool
base_cfg_t::setuid ()
{
  bool ret = true;
  if (getuid() != 0)
    ret = false;
  else if ((_group && ::setgid (_group->getid ()) < 0) ||
	(_user && ::setuid (_user->getid ())) < 0)
    ret = false;
  return ret;
}

bool
config_parser_t::do_file (const str &fn)
{
  bool rc = false;
  str hsh;
  if (!(hsh = file2hash (fn))) {
    warn << "Cannot open config file: " << fn << "\n";
  } else {
    if (_seen[hsh]) {
      warn << "File included more than once: " << fn << "\n";
    } else {
      _seen.insert (hsh);
      warn << "Using config file: " << fn << "\n";
      if (!parse_file (fn)) {
	warn << "Config file parse failed: " << fn << "\n";
      } else {
	rc = true;
      }
    }
  }
  return rc;
}

bool
config_parser_t::run_configs (const str &fn)
{
  return (do_file (fn) && post_config (fn));
}

void
config_parser_t::include (vec<str> s, str loc, bool *errp)
{
  if (s.size () != 2) {
    warn << loc << ": usage: include <file>\n";
    *errp = true;
  } else if (!do_file (s[1])) {
    *errp = true;
  }
}

str
file2hash (const str &fn, struct stat *sbp)
{
#define BUFSIZE 4096
  char buf[BUFSIZE];
  char digest[sha1::hashsize];
  struct stat sb;
  if (!sbp)
    sbp = &sb;
  if (access (fn.cstr (), F_OK | R_OK) != 0)
    return NULL;
  if (stat (fn.cstr (), sbp) != 0 || !S_ISREG (sbp->st_mode))
    return NULL;
  int fd = open (fn.cstr (), O_RDONLY);
  if (fd < 0)
    return NULL;
  size_t n;
  sha1ctx sc;
  while ((n = read (fd, buf, BUFSIZE))) {
    sc.update (buf, n);
  }
  sc.final (digest);
  close (fd);
  return armor32 (digest, sha1::hashsize);
#undef BUFSIZE
}
