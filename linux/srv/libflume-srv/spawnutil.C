#include "spawnutil.h"
#include "parseopt.h"
#include "iddutil.h"
#include <sys/types.h>
#include <errno.h>
#include "rxx.h"
#include "asyncutil.h"

extern int optind;

static void 
usage (str loc)
{
  if (loc && loc.len () > 0)
    warnx << progname << ": " << loc << " ";
  warnx << "usage: <spawner> \n" 
    "\t-L <ld-library-path>\n";
}

flmspwn::cfg_t::cfg_t ()
  : base_cfg_t (),
    _ld_library_path (default_ld_library_path),
    _linker (default_linker)
{}
    

void
flmspwn::cfg_t::init ()
{
}

bool
flmspwn::cfg_t::parseopts (int argc, char *const argv[], str loc)
{
  int id;
  int ch;
  bool rc = true;

  _prog = argv[0];

  getopt_reset ();
  
  while ((ch = getopt (argc, argv, "c:u:g:l:L:")) != -1) {
    switch (ch) {
    case 'l':
      _linker = optarg;
      break;
    case 'L':
      _ld_library_path = optarg;
      break;
    case 'c':
      _chroot_dir = optarg;
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
    default:
      rc = false;
      break;
    }
  }

  argv += optind;
  argc -= optind;

  if (argc != 0)
    rc = false;

  if (!rc)
    usage (loc);

  return rc;
}

bool
flmspwn::cfg_t::to_argv (vec<str> *argv) const
{
  str err;
  if ((err = can_exec (_prog))) {
    warn << "spawner execution error: " << err << "\n";
    return false;
  } else {
    argv->push_back (_prog);
    if (_chroot_dir)
      add_opt (argv, "-c", _chroot_dir);
    add_opt (argv, "-L", _ld_library_path);
    add_opt (argv, "-l", _linker);
    add_opt (argv, "-u", _user->getname ());
    add_opt (argv, "-g", _group->getname ());
  }

  return true;
}

str
flmspwn::cfg_t::to_str () const
{
  strbuf b;
  b << "LD_LIBRARY_PATH=" << _ld_library_path << "; ";
  b << "Linker=" << _linker << "; ";
  b << "User=" << _user->getname () << "; ";
  if (_chroot_dir)
    b << "Chroot=" << _chroot_dir << "; ";
  b << "Group=" << _group->getname () ;
    
  return b;
}

void
flmspwn::res2res (const spawn_i_res_t &ires, spawn_res_t *res)
{
  assert (ires.status != FLUME_OK);
  res->set_status (ires.status);
  switch (res->status) {
  case FLUME_EPERM:
    *res->eperm = *ires.eperm;
    break;
  case FLUME_ERPC:
    *res->rpcerr = *ires.rpcerr;
    break;
  default:
    break ;
  }
}

void
flmspwn::arg2arg (const spawn_arg_t &in, spawn_i_arg_t *out)
{
  out->c_args = in.c_args;
  out->opts = in.opts;
  out->label_changes = in.label_changes;
  out->claim_fds = in.claim_fds;
  out->I_min = in.I_min;
}

void
flmspwn::res2res (const flume_res_t &in, file_res_t *out)
{
  out->set_status (in.status);
  if (in.status == FLUME_EPERM) {
    *out->eperm = *in.eperm;
  } else if (in.status == FLUME_ERPC) {
    *out->error = *in.rpcerror;
  }
}
