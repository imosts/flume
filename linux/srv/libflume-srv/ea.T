
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

#ifdef __linux__
#define HAVE_EXTATTR
#endif

#ifdef HAVE_EXTATTR
# ifdef __linux__
#  include <sys/xattr.h> 
# else
#  include <sys/extattr.h>
#  include <ufs/ufs/extattr.h>
# endif

#endif

namespace fs {

#ifdef HAVE_EXTATTR

  //----------------------------------------------------------------------

  static int
  set_ext_attr (str fn, str attrname, str val) {

#ifdef __linux__
    str key = strbuf () << "user." << attrname;
    ssize_t rc = setxattr (fn.cstr (), key.cstr (), val.cstr (), val.len (), 0);
    if (rc < 0)
      warn ("%s:%s, got EXTATTR error %d, fn %s\n", 
            __FL__, __func__, errno, fn.cstr ());
    return val.len ();
#else
    return extattr_set_file (fn.cstr (), EXTATTR_NAMESPACE_USER, 
                             attrname.cstr (), val.cstr (), val.len ());
#endif
  }

  //----------------------------------------------------------------------

  static int
  fset_ext_attr (int fd, str attrname, str val) {

#ifdef __linux__
    str key = strbuf () << "user." << attrname;
    ssize_t rc = fsetxattr (fd, key.cstr (), val.cstr (), val.len (), 0);
    if (rc < 0)
      warn ("%s:%s, got EXTATTR error %d fd %d\n", 
            __FL__, __func__, errno, fd);
    return val.len ();
#else
    return extattr_set_fd (fd, EXTATTR_NAMESPACE_USER, 
                           attrname.cstr (), val.cstr (), val.len ());
#endif
  }

  //----------------------------------------------------------------------

  static int
  get_ext_attr (str fn, str attrname, char *val, int len) {

#ifdef __linux__
    str key = strbuf () << "user." << attrname;
    ssize_t rc = getxattr (fn.cstr (), key.cstr (), val, len);
    if (rc < 0)
      warn ("%s:%s, got EXTATTR error %d fn %s\n", 
            __FL__, __func__, errno, fn.cstr ());
    return rc;
#else
    return extattr_get_file (fn.cstr (), EXTATTR_NAMESPACE_USER, 
                             attrname.cstr (), val, len);
#endif
  }

  //----------------------------------------------------------------------

  static int
  fget_ext_attr (int fd, str attrname, char *val, int len) {

#ifdef __linux__
    str key = strbuf () << "user." << attrname;
    ssize_t rc = fgetxattr (fd, key.cstr (), val, len);
    if (rc < 0)
      warn ("%s:%s, got EXTATTR error %d fd %d\n",
            __FL__, __func__, errno, fd);
    return rc;
#else
    return extattr_get_fd (fd, EXTATTR_NAMESPACE_USER, 
                           attrname.cstr (), val, len);
#endif
  }
  //----------------------------------------------------------------------

  static int
  enable_ext_attr (const str fn, const str attrname, const str &attrfile) {

#ifdef __linux__
    // Do nothing
    return 0;
#else
    return extattrctl (fn.cstr (), UFS_EXTATTR_CMD_ENABLE, 
                       attrfile.cstr (), 
                       EXTATTR_NAMESPACE_USER,
                       attrname);
#endif
  }
#endif
  //----------------------------------------------------------------------

  flume_status_t 
  ea_mgr_t::enable_attr (const str &fn, const str &attrfile)
  {
    flume_status_t rc = FLUME_OK;
    int err = 0;
    const char *attrname = labelset_attrname;

#ifdef HAVE_EXTATTR
    err = enable_ext_attr (fn, attrname, attrfile);
#else
    warn ("%s:%s called, but no EXTATTR support!\n", __FL__, __func__);
    rc = FLUME_ERR;
#endif
    
    if (err < 0) {
      warn ("Error in external attribute enable: "
	    "[file=%s] [backingfile=%s] [attrname=%s]: %m\n",
	    fn.cstr (), attrfile.cstr (), attrname);
      rc = FLUME_EATTR;
    }
    
    return rc;
  }

  //----------------------------------------------------------------------

  static void
  mk_extattr (flume_extattr_t *out, const frozen_labelset_t &in)
  {
    out->ls = in;
    sha1_hashxdr (out->hash.base (), out->ls);
  }

  //----------------------------------------------------------------------

  static bool
  chk_extattr (const flume_extattr_t &in)
  {
    char buf[SHA1SZ];
    sha1_hashxdr (buf, in.ls);
    return (memcmp (buf, in.hash.base (), SHA1SZ) == 0);
  }

  //----------------------------------------------------------------------

  void
  real_ea_mgr_t::setlabelset_impl (int fd, const str &fn, 
				   const frozen_labelset_t &in,
				   flume_status_cb_t cb)
  {
    flume_status_t rc = FLUME_OK;
    const char *attrname = fs::labelset_attrname;
    ssize_t res;
    
    flume_extattr_t tea;
    mk_extattr (&tea, in);
    str s = xdr2str (tea);
    
#ifdef HAVE_EXTATTR
    
    if (fd >= 0) {
      res = fset_ext_attr (fd, attrname, s);
    } else if (fn) {
      res = set_ext_attr (fn, attrname, s);
    } else {
      panic ("bad call to setlabelset_impl\n");
    }
    
#else
    warn ("%s:%s called, but no EXTATTR support!\n", __FL__, __func__);
#endif

    rc = FLUME_EATTR;
    if (res < 0) {
      warn ("Error in extattr_set %s: %m\n", attrname);
    } else if (res != ssize_t(s.len ())) {
      warn << "Setting attribute " << attrname 
	   << " resulted in short write.\n";
      warn << "Expected to write " << s.len() << " bytes; "
	   << "only wrote " << res << "\n";
    } else {
      rc = FLUME_OK;
    }
    cb->trigger (rc);
  }  

  //-----------------------------------------------------------------------
  
#define LSSZ (sizeof (flume_extattr_t))

  void
  real_ea_mgr_t::getlabelset_impl (int fd, const str &fn, 
				   frozen_labelset_t *out,
				   flume_status_cb_t cb)
  {
    flume_status_t rc (FLUME_EATTR);
    size_t len = LSSZ;
    mstr m (len);
    ssize_t s = 0;
    
#ifdef HAVE_EXTATTR
    const char *attrname = fs::labelset_attrname;

    if (fd >= 0) {
      s = fget_ext_attr (fd, attrname, m.cstr (), len);
    } else if (fn) {
      s = get_ext_attr (fn, attrname, m.cstr (), len);
    } else {
      panic ("bad call to getlabelset_impl\n");
    }
#else
    warn ("%s:%s called, but no EXTATTR support!\n", __FL__, __func__);
#endif
    
    if (s >= 0) {
      m.setlen (s);
      flume_extattr_t tea;
      if (!str2xdr (tea, m)) {
	rc = FLUME_EXDR;
      } else if (!chk_extattr (tea)) {
	rc = FLUME_ECHECKSUM;
      } else {
	rc = FLUME_OK;
	*out = tea.ls;
      }
    }
    cb->trigger (rc);
  }
  
  //-----------------------------------------------------------------------

  u_int64_t
  gea_t::to_b60 (const flume_extattr_t &t)
  {
    char m[sha1::hashsize];
    sha1_hashxdr (m, t);
    u_int64_t x;
    memcpy ((void *)&x, m, sizeof (x));
    x = x >> 4;
    return x;
  }

  //-----------------------------------------------------------------------

  u_int32_t 
  gea_t::mask_bits (u_int64_t in)
  {
    return ((in & 0x3fffffff) | (0x40000000));
  }

  //-----------------------------------------------------------------------

  void
  gea_t::b60_to_uid_gid (u_int64_t bits, uid_t *uid, gid_t *gid)
  {
    *uid = mask_bits (bits);
    bits = bits >> 30;
    *gid = mask_bits (bits);
  }

  //-----------------------------------------------------------------------

  u_int64_t 
  gea_t::unmask_bits (u_int32_t x)
  {
    return (x & ~(0x40000000));
  }

  //-----------------------------------------------------------------------

  u_int64_t
  gea_t::uid_gid_to_b60 (uid_t uid, gid_t gid)
  {
    u_int64_t ret = unmask_bits (gid);
    ret = ret << 30;
    ret |= unmask_bits (uid);
    return ret;
  }

  //-----------------------------------------------------------------------

  tamed void
  ghetto_ea_mgr_t::setlabelset_impl_T (int fd, str fn,
				       const frozen_labelset_t &in,
				       flume_status_cb_t cb)
  {
    tvars {
      flume_extattr_t tea;
      u_int64_t b60;
      flume_status_t st;
    }
    mk_extattr (&tea, in);
    b60 = gea_t::to_b60 (tea);
    twait { _idd->new_gea (b60, tea, mkevent (st)); }
    if (st == FLUME_EEXIST)
      st = FLUME_OK;
    if (st == FLUME_OK) {
      uid_t u;
      gid_t g;
      gea_t::b60_to_uid_gid (b60, &u, &g);
      int rc = -1;
      if (fd >= 0) {
	rc = fchown (fd, u, g);
	if (rc < 0)
	  warn ("fchown: %m\n");
      } else if (fn) {
	rc = chown (fn.cstr (), u, g);
	if (rc < 0) 
	  warn ("chown (%s): %m\n", fn.cstr ());
      } else {
	warn ("setlabelset_impl: no fn or fd given!\n");
      }
      if (rc < 0) {
	st = errno2err (false);
      }
    }
    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  flume_status_t
  errno2err (bool pdir)
  {
    switch (errno) {
    case EACCES: return FLUME_EPERM;
    case ENOTDIR: return FLUME_EPATH;
    case ENOENT: return (pdir ? FLUME_EPATH : FLUME_ENOENT);
    case ENOTEMPTY: return FLUME_ENOTEMPTY;
    case EEXIST: return FLUME_EEXIST;
    case EISDIR: return FLUME_EISDIR;
    case EINVAL: return FLUME_EINVAL;
    default:
      warn ("unhandled Unix error: %m\n");
      return FLUME_ERR;
    }
  }

  //-----------------------------------------------------------------------

  tamed void
  ghetto_ea_mgr_t::getlabelset_impl_T (int fd, str fn,
				       frozen_labelset_t *in,
				       flume_status_cb_t cb)
  {
    tvars {
      struct stat sb;
      int rc;
      flume_status_t st;
      u_int64_t gea;
      flume_extattr_t tea;
    }

    rc = -1;
    if (fd >= 0) {
      rc = fstat (fd, &sb);
      if (rc < 0) {
	warn ("fstat: %m\n");
      }
    } else if (fn) {
      rc = stat (fn, &sb);
      if (rc < 0) {
	warn ("stat (%s): %m\n", fn.cstr ());
      }
    } else {
      warn ("getlabelset_impl: no fd or no given\n");
    }

    if (rc < 0) {
      st = errno2err (false);
    } else {
      gea = gea_t::uid_gid_to_b60 (sb.st_uid, sb.st_gid);
      twait { _idd->expand_gea (gea, &tea, mkevent (st)); }
      if (st == FLUME_OK) {
	if (!chk_extattr (tea)) {
	  st = FLUME_ECHECKSUM;
	} else {
	  *in = tea.ls;
	}
      }
    }
    cb->trigger (st);
  }

  //-----------------------------------------------------------------------

  void 
  ea_mgr_t::setlabelset (int fd, const frozen_labelset_t &in, 
			 flume_status_cb_t cb)
  {
    setlabelset_impl (fd, NULL, in, cb);
  }

  //-----------------------------------------------------------------------

  void 
  ea_mgr_t::setlabelset (const str &f, const frozen_labelset_t &in, 
			 flume_status_cb_t cb)
  {
    setlabelset_impl (-1, f, in, cb);
  }

  //-----------------------------------------------------------------------

  void
  ea_mgr_t::getlabelset (const str &f, frozen_labelset_t *out, 
			 flume_status_cb_t cb)
  {
    getlabelset_impl (-1, f, out, cb);
  }

  //-----------------------------------------------------------------------

  void
  ea_mgr_t::getlabelset (int f, frozen_labelset_t *out, flume_status_cb_t cb)
  {
    getlabelset_impl (f, NULL, out, cb);
  }

  //-----------------------------------------------------------------------

}
