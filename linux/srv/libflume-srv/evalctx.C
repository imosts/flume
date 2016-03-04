
#include "evalctx.h"


namespace eval {

  nil_t nil_obj;

  void
  ctx_t::error (flume_status_t st,
		obj_t o1, obj_t o2, obj_t o3, obj_t o4, obj_t o5,
		obj_t o6, obj_t o7, obj_t o8, obj_t o9, obj_t o10)
  {
    obj_t *v[] = { &o1, &o2, &o3, &o4, &o5, &o6, &o7, &o8, &o9, &o10, NULL };
    vec<str> tmp;
    strbuf b;
    
    _status = st;

    for (obj_t **p = v; *p; p++) {
      if (**p) {
	str s = (*p)->to_str ();
	if (s) b << s;
	else b << "(null)";
	tmp.push_back (s);
	
      }
    }
    _msgs.push_back (b);
  }


  str
  ctx_t::to_str () const 
  {
    strbuf b;
    for (size_t i = 0; i < _msgs.size (); i++) {
      if (i != 0)
	b << "\n";
      b << _msgs[i];
    }
    return b;
  }

}
