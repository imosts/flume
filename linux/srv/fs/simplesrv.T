
// -*-c++-*-
#include "fs.h"
#include <sys/types.h>
#include <errno.h>
#include "fsutil.h"
#include "flume_srv_const.h"

namespace fs {

  simple_srv_t::simple_srv_t (const cfg_t &o) : base_srv_t (o) {}

  //-----------------------------------------------------------------------

  simple_srv_t::~simple_srv_t () {}

  //-----------------------------------------------------------------------

  void
  simple_srv_t::file2str (str fn, cbis_t cb)
  {
    str s = ::file2str (fn);
    if (s) {
      cb->trigger (0, s);
    } else {
      cb->trigger (-1, NULL);
    }
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::writefile_impl (int fd, const str &data, flume_status_cb_t cb)
  {
    strbuf b;
    b << data;
    int rc = b.tosuio ()->output (fd);
    flume_status_t st = FLUME_OK;
    if (rc < 0) {
      st = errno2err (false);
    }
    cb->trigger (st);
  }


  //-----------------------------------------------------------------------

  void
  simple_srv_t::mksock_impl (int dfd, const str &f, int mode, open_cb_t cb,
			     struct stat *sb)
  {
    flume_status_t ret;
    int fd = -1;
    if (fchdir (dfd) < 0) {
      warn ("Could not fchdir() into fd %d: %m\n", dfd);
      ret = errno2err (true);
    } else {
      fd = unixsocket (f.cstr ());
      if (fd >= 0) {
	if (chmod (f.cstr (), mode) < 0) {
	  warn ("Unexpected fchmod() failure on %s: %m\n", f.cstr ());
	  ret = errno2err (false);
	} else {
	  ret = FLUME_OK;
	}
	if (sb && ::stat (f.cstr (), sb) < 0) {
	  warn ("Unexpected stat() failure on %s: %m\n", f.cstr ());
	  ret = errno2err (false);
	}
      } else {
        warn ("Unexpected unixsocket() failure on %s: %m\n", f.cstr ());
	ret = errno2err (false);
      }
    }
    cb->trigger (ret, fd);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::rmdir_impl (int dfd, const str &f, flume_status_cb_t cb)
  {
    flume_status_t ret;
    if (dfd < 0)
      dfd = AT_FDCWD;

    if (unlinkat (dfd, f.cstr (), AT_REMOVEDIR) < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
    }

    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::link_or_rename_impl (int dfd, const str &to, const str &from,
				     bool lnk, flume_status_cb_t cb)
  {
    flume_status_t ret;
    if (fchdir (dfd) < 0) {
      ret = errno2err (true);
    } else if (lnk && link (from.cstr(), to.cstr ()) < 0) {
      ret = errno2err (false);
    } else if (!lnk && rename (from.cstr (), to.cstr ()) < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
    }
    cb->trigger (ret);
  }


  //-----------------------------------------------------------------------

  void
  simple_srv_t::symlink_impl (int dfd, const str &to, const str &from,
			      flume_status_cb_t cb)
  {
    flume_status_t ret;
    if (fchdir (dfd) < 0) {
      ret = errno2err (true);
    } else if (::symlink (from.cstr(), to.cstr ()) < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
    }
    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::mkdir_impl (int dfd, const str &f, int mode, open_cb_t cb)
  {
    flume_status_t ret;
    int fd = -1;
    if (dfd < 0)
      dfd = AT_FDCWD;

    int rc = mkdirat (dfd, f.cstr (), mode);
    if (rc < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
      if ((fd = openat (dfd, f.cstr (), O_RDONLY, 0)) < 0) {
	warn ("Unexpected open failure on dir=%s: %m\n", f.cstr ());
	unlinkat (dfd, f.cstr (), AT_REMOVEDIR);
	ret = FLUME_ENOENT;
      }
    }

    cb->trigger (ret, fd);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::open_impl (int dfd, const str &f, int flags, int mode,
			   open_cb_t cb, bool *file_existed_p)
  {
    flume_status_t ret;
    int fd = -1;

    if (dfd < 0) 
      dfd = AT_FDCWD;

    if ((flags & O_CREAT) && file_existed_p) {
      struct stat sb;
      *file_existed_p = (fstatat (dfd, f.cstr (), &sb, 0) >= 0);
    }

    if ((fd = openat (dfd, f.cstr (), flags, mode)) < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
    }
    
    cb->trigger (ret, fd);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::stat_impl (int dfd, const str &f, struct stat *sb,
			   flume_status_cb_t cb, bool use_lstat)
  {
    flume_status_t ret;
    int fl = use_lstat ? AT_SYMLINK_NOFOLLOW : 0;
    if (dfd < 0)
      dfd = AT_FDCWD;

    if (fstatat (dfd, f.cstr (), sb, fl) < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
    }

    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  void 
  simple_srv_t::access_impl (int dfd, const str &path, int mode, 
			     flume_status_cb_t cb)
  {
    flume_status_t ret;

    if (dfd < 0)
      dfd = AT_FDCWD;

    int rc = faccessat (dfd, path.cstr (), mode, 0);
    if (rc < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
    }

    cb->trigger (ret);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::readlink_impl (int dfd, const str &f, str *out, 
			       flume_status_cb_t cb)
  {
    char buf[MAXPATHLEN];
    flume_status_t ret;
    if (dfd >= 0 && fchdir (dfd) < 0) {
      ret = errno2err (true);
    } else {
      int rc = readlink (f.cstr (), buf, MAXPATHLEN);
      if (rc < 0) {
	ret = errno2err (false);
      } else {
	*out = str (buf, rc);
	ret = FLUME_OK;
      }
    }
    cb->trigger (ret);
  }


  //-----------------------------------------------------------------------

  void
  simple_srv_t::open_for_stat_impl (int dfd, const str &f, open_cb_t cb)
  {
    flume_status_t ret = FLUME_EPATH;
    int fd = -1;
    if (dfd >= 0 && fchdir (dfd) < 0) {
      ret = errno2err (true);
    } else {
      struct stat sb;
      int rc = ::stat (f.cstr (), &sb);
      if (rc < 0) {
	ret = errno2err (false);
      } else {
	if (S_ISSOCK (sb.st_mode)) {
	  fd = unixsocket_connect (f.cstr ());
	} else {
	  fd = ::open (f.cstr (), O_RDONLY);
	}
	if (fd < 0) 
	  ret = errno2err (false);
	else
	  ret = FLUME_OK;
      }
    }
    cb->trigger (ret, fd);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::unlink_impl (int pdh, const str &f,
			   unlink_cb_t cb)
  {
    flume_status_t ret;
    if (pdh < 0)
      pdh = AT_FDCWD;

    if (unlinkat (pdh, f.cstr (), 0) < 0) {
      ret = errno2err (false);
    } else {
      ret = FLUME_OK;
    }
    
    cb->trigger (ret);
  }


  //-----------------------------------------------------------------------

  void
  simple_srv_t::unixconnect_impl (int dfd, const str &f, open_cb_t cb)
  {
    flume_status_t ret;
    int sfd = -1;
    if (dfd >= 0 && fchdir (dfd) < 0) {
      ret = errno2err (true);
    } else {
      sfd = unixsocket_connect (f);
      ret = (sfd >= 0) ? FLUME_OK : FLUME_ECONREFUSED;
    }
    cb->trigger (ret, sfd);
  }
  
  //-----------------------------------------------------------------------
    
  void
  simple_srv_t::str2file (str s, str f, int mode, cbi cb)
  {
    bool b = ::str2file (f, s, mode);
    cb->trigger (b ? -1 : 0);
  }

  //-----------------------------------------------------------------------

  void
  simple_srv_t::opendir (const str &d, callback<void, DIR *>::ref cb)
  {
    cb->trigger (::opendir (d.cstr ()));
  }

  //-----------------------------------------------------------------------

  tamed void
  simple_srv_t::get_frozen_labelset_T (int fd, frozen_labelset_t *ls, 
				       flume_status_cb_t cb)
  {
    tvars {
      flume_status_t rc (FLUME_OK);
    }
    twait { _cfg.ea_mgr ()->getlabelset (fd, ls, mkevent (rc)); }
    if (rc == FLUME_ENOENT)
      rc = FLUME_EATTR;
    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  tamed void
  simple_srv_t::get_frozen_labelset_by_fn_T (int dfd, const str &fn,
					     frozen_labelset_t *ls, 
					     flume_status_cb_t cb)
  {
    tvars {
      flume_status_t rc (FLUME_OK);
    }
    if (fchdir (dfd) < 0) {
      rc = FLUME_EPATH;
    }

    twait { _cfg.ea_mgr ()->getlabelset (fn, ls, mkevent (rc)); }
    if (rc == FLUME_ENOENT)
      rc = FLUME_EATTR;
    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  tamed void
  simple_srv_t::set_frozen_labelset_T (int fd, 
				       const frozen_labelset_t &ls,
				       flume_status_cb_t cb)
  {
    tvars {
      flume_status_t rc (FLUME_OK);
    }

    twait { _cfg.ea_mgr ()->setlabelset (fd, ls, mkevent (rc)); }
    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  tamed void
  simple_srv_t::set_frozen_labelset_by_fn_T (int dfd, const str &fn,
					     const frozen_labelset_t &ls,
					     flume_status_cb_t cb)
  {
    tvars {
      flume_status_t rc (FLUME_OK);
    }
    if (fchdir (dfd) < 0) {
      rc = FLUME_EPATH;
    }

    twait { _cfg.ea_mgr ()->setlabelset (fn, ls, mkevent (rc)); }

    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  void 
  simple_srv_t::utimes_impl (int fd, x_utimes_t *xut, flume_status_cb_t cb)
  {
    struct timeval tv[2];
    struct timeval *tvp = NULL;
    if (xut) {
      xdr2timeval (xut->atime, &tv[0]);
      xdr2timeval (xut->mtime, &tv[1]);
      tvp = tv;
    }
    flume_status_t stat = FLUME_OK;
    int rc = futimes (fd, tvp);
    if (rc < 0) {
      stat = errno2err (false);
    }
    cb->trigger (stat);
  }

  //-----------------------------------------------------------------------
};
