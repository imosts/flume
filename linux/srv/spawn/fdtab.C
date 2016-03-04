
#include "spawn.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

namespace flmspwn {

  //-----------------------------------------------------------------------

  /*
   * hold empty hole places in the FD tab, under maxfd.  Do so by dup'ing
   * openfd a bunch of times.
   */
  void
  fdtab_t::hold_places (int maxfd, int openfd)
  {
    for (int i = 0; i < maxfd; i++) {
      if (!_tab[i]) {
	int nfd = dup (openfd);
	assert (nfd == i);
	insert (nfd, false, false, 
		strbuf("[%" PRIx64 "] holder; [copy of %d]", 
		       getflmpid().value (), openfd));
      }
    }
    if (_minfd < maxfd)
      _minfd = maxfd;
  }

  //-----------------------------------------------------------------------

  void
  fdtab_t::close (int fd)
  {
    FLUMEDBG4(FDS, CHATTER, "[%" PRIx64 "] close fd=%d\n", 
	          getflmpid ().value (), fd);
    fd_t *obj = _tab[fd];
    if (obj) {
      close (obj, true);
    }
  }

  //-----------------------------------------------------------------------

  void
  fdtab_t::close (fd_t *obj, int del)
  {
    FLUMEDBG4(FDS, CHATTER, "[%" PRIx64 "] close (%s); unreg: %d\n", 
	     getflmpid ().value (), obj->desc (), obj->_dereg);
    assert (_tab[obj->_fd]);

    if (obj->_dereg) {
      fdcb (obj->_fd, selread, NULL);
      fdcb (obj->_fd, selwrite, NULL);
    }

    ::close (obj->_fd);
    remove (obj);
    if (del)
      delete obj;
  }

  //-----------------------------------------------------------------------
  
  void
  fdtab_t::remove (fd_t *obj)
  {
    _tab.remove (obj);
    _lst.remove (obj);
  }

  //-----------------------------------------------------------------------

  void
  fdtab_t::insert (fd_t *obj)
  {
    assert (obj->_fd >= _minfd);
    FLUMEDBG4(FDS, CHATTER, "[%" PRIx64 "]: insert (%s) %d %d\n", 
	     getflmpid ().value (), obj->desc (), obj->_keep_open,
	     obj->_dereg);

    assert (!_tab[obj->_fd]);
    _tab.insert (obj);
    _lst.insert_tail (obj);
  }

  //-----------------------------------------------------------------------

  void
  fdtab_t::insert (int i, bool keep_open, bool dereg, const str &desc)
  {
    return insert (New fd_t (i, keep_open, dereg, desc));
  }

  //-----------------------------------------------------------------------
    
  void 
  fdtab_t::close_all ()
  {
    fd_t *n, *p;

    FLUMEDBG4(FDS, CHATTER, "[%" PRIx64 "] close_all()\n", 
	          getflmpid ().value ());

    for (p = _lst.first; p; p = n) {
      n = _lst.next (p);
      if (!p->_keep_open) {
	close (p, true);
      }
    }
  }

  //-----------------------------------------------------------------------

}
