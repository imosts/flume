// -*-c++-*-

#include "fs.h"
#include "aiod.h"

//-----------------------------------------------------------------------

namespace fs { 

  tamed void
  aiod_srv_t::file2str_T (str fn, cbis_t cb)
  {
    tvars {
      str rfn;
      int rc;
      ptr<aiofh> fh;
      ptr<aiobuf> buf, b2;
      off_t pos, sz;
      strbuf b;
      struct stat *sb;
      str ret;
      ssize_t rsz;
      bool eof;
    }
    rfn = jail2real (fn);
    twait { _aiod->open (rfn, O_RDONLY, 0, mkevent (fh, rc)); }
    if (rc == 0) {
      twait { fh->fstat (mkevent (sb, rc)); }
      if (rc == 0) {
	sz = sb->st_size;
	if (!(buf = _aiod->bufalloc (blocksz))) {
	  rc = ENOMEM;
	} else {
	  eof = false;
	  for (pos = 0; pos < sz && rc == 0 && eof; pos += blocksz) {
	    twait { fh->read (pos, buf, mkevent (b2, rsz, rc)); }
	    if (rc != 0) {
	      warn ("Read error on file (%s): %m\n", fn.cstr ());
	    } else if (rsz < 0) {
	      warn ("Got unexpected failed read on file: %s\n", fn.cstr ());
	    } else {
	      if (rsz < blocksz) {
		eof = true;
	      } 
	      b.tosuio ()->copy (b2->base (), rsz);
	    }
	  }
	  if (rc == 0) {
	    if (b.tosuio ()->resid () != size_t (sz)) {
	      warn << "While reading " << fn << ": "
		   << "exepcted " << sz << "bytes; got " 
		   << b.tosuio ()->resid () << " bytes instead\n";
	    }
	    ret = b;
	  }
	}
      } else {
	warn << "fstat failed on file: " << fn << "\n";
      }
    }
    cb->trigger (rc, ret);
  }
  
  //-----------------------------------------------------------------------
  
  tamed void
  aiod_srv_t::str2file_T (str fn, str s, int mode, cbi cb)
  {
    tvars {
      str rfn;
      ptr<aiofh> fh;
      ptr<aiobuf> buf,b2;
      int rc;
      const char *cp;
      off_t pos;
      const char *ep (s.cstr () + s.len ());
      ssize_t wsz, bsz;
    }
    
    rfn = jail2real (fn);
    twait { _aiod->open (rfn, O_WRONLY, mode, mkevent (fh, rc)); }
    if (rc == 0) {
      if (!(buf = _aiod->bufalloc (blocksz))) {
	rc = ENOMEM;
      } else {
	for (pos = 0, cp = s.cstr (); cp < ep && rc == 0; 
	   pos += blocksz, cp += blocksz) {
	  bsz = min<ssize_t> (blocksz, ep - cp);
	  memcpy (buf->base (), cp, bsz);
	  twait { fh->write (pos, buf, mkevent (b2, wsz, rc)); }
	  if (rc != 0) {
	    warn ("Bad write to file (%s): %d\n", fn.cstr (), rc);
	  } else if (wsz != bsz) {
	    warn ("Short write to file (%s): expected %zd bytes, got %zd\n",
		  fn.cstr (), bsz, wsz);
	    rc = EIO;
	  }
	}
      }
      twait { fh->close (mkevent (rc)); }
      if (rc != 0) {
	warn ("Close failed on file (%s): %d\n", fn.cstr (), rc);
      }
    }
    cb->trigger (rc);
  }

  //-----------------------------------------------------------------------

  bool 
  aiod_srv_t::v_init ()
  {
    _aiod = New aiod (_cfg._n_aiods, _cfg._shmsize, _cfg._maxbuf);
    return true;
  }

  //-----------------------------------------------------------------------

  aiod_srv_t::~aiod_srv_t ()
  {
    if (_aiod) _aiod->finalize ();
  }
  
  //-----------------------------------------------------------------------

  aiod_srv_t::aiod_srv_t (const cfg_t &o) 
    : base_srv_t (o), _aiod (NULL) {}
  
};

//-----------------------------------------------------------------------
  
