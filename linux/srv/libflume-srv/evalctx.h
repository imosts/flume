

// -*-c++-*-

#include "flume_prot.h"
#include "ihash.h"
#include "qhash.h"
#include "flume_bf60.h"
#include "tame.h"
#include "keyfunc.h"
#include "flume_ev_labels.h"

#ifndef __LIBFLUME_EVALCTX_H__
#define __LIBFLUME_EVALCTX_H__

namespace eval { 

  struct nil_t {};
  extern nil_t nil_obj;

  class obj_t {
  public:
    enum { mode = LABEL_NO_O } ;

    obj_t (nil_t) : _stat (FLUME_OK), _set (false) {}
    obj_t (const char *s) : _stat (FLUME_OK), _set (true), _s (s) {}
    obj_t (const str &s) : _stat (FLUME_OK), _set (true), _s (s) {}
    obj_t (ptr<const label_t> l) : 
      _stat (FLUME_OK), _set (true), _s (l ? l->to_str () : str ()) {}
    obj_t (ptr<const capset_t> l) : 
      _stat (FLUME_OK), _set (true), _s (l ? l->label_t::to_str () : str ()) {}
    obj_t (ptr<capset_t> l) :
      _stat (FLUME_OK), _set (true), _s (l ? l->label_t::to_str () : str ()) {}
    obj_t (const label_t *l) : 
      _stat (FLUME_OK), _set (true), _s (l ? l->to_str () : str ()) {}
    obj_t (const label_t &l) : 
      _stat (FLUME_OK), _set (true), _s (l.to_str ()) {}
    obj_t (const labelset_t *ls) : 
      _stat (FLUME_OK), _set (true), _s (ls ? ls->to_str (mode) : str ()) {}
    obj_t (ptr<const labelset_t> ls) :
      _stat (FLUME_OK), _set (true), _s (ls ? ls->to_str (mode) : str ()) {}
    obj_t (ptr<labelset_t> ls) :
      _stat (FLUME_OK), _set (true), _s (ls ? ls->to_str (mode) : str ()) {}
    obj_t (const labelset_t &l) : 
      _stat (FLUME_OK), _set (true), _s (l.to_str (mode)) {}
    obj_t (const x_label_t &x) : 
      _stat (FLUME_OK), _set (true), _s (label_t (x).to_str ()) {}
    obj_t (const handle_t &h) :
      _stat (FLUME_OK), _set (true), _s (h.to_str ()) {}

    operator bool() const { return _set; }
    operator str() const { return to_str (); }
    str to_str () const { return _s; }


  private:
    flume_status_t _stat;
    bool _set;
    str _s;
  };

  class ctx_t : public virtual refcount {
  public:

    template<class T> void
    to_xdr (T *in)
    {
      in->set_status (_status);
      if (_status == FLUME_EPERM) {
	in->eperm->desc = to_str ();
      }
    }

    static ptr<ctx_t> alloc () { return New refcounted<ctx_t> (); }

    str to_str () const;

    flume_status_t status () const { return _status; }

    bool perm_error () const { return _status == FLUME_EPERM; }
    

    ctx_t (flume_status_t st = FLUME_OK) : _status (st) {}
    
    void error (obj_t o1 = nil_obj,
		obj_t o2 = nil_obj,
		obj_t o3 = nil_obj,
		obj_t o4 = nil_obj,
		obj_t o5 = nil_obj,
		obj_t o6 = nil_obj,
		obj_t o7 = nil_obj,
		obj_t o8 = nil_obj,
		obj_t o9 = nil_obj,
		obj_t o10 = nil_obj)
    {
      error (FLUME_EPERM, o1, o2, o3, o4, o5, o6, o7, o8, o9, o10); 
    }
    
    void error (flume_status_t stat,
		obj_t o1 = nil_obj,
		obj_t o2 = nil_obj,
		obj_t o3 = nil_obj,
		obj_t o4 = nil_obj,
		obj_t o5 = nil_obj,
		obj_t o6 = nil_obj,
		obj_t o7 = nil_obj,
		obj_t o8 = nil_obj,
		obj_t o9 = nil_obj,
		obj_t o10 = nil_obj);
    
  private:
    flume_status_t _status;
    vec<str> _msgs;
  };

}

#endif /* __LIBFLUME_EVALCTX_H__ */
