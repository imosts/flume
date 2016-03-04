
// -*-c++-*-
/* $Id: pslave.h 1682 2006-04-26 19:17:22Z max $ */

#ifndef _LIBFLUME_ASYNCUTIL_H_
#define _LIBFLUME_ASYNCUTIL_H_

#include "async.h"
#include "tame.h"

void debug_attach (cbv cb, str s = NULL, CLOSURE);
void safevtrig (cbv::ptr *c);

void add_flag (vec<str> *v, const char *f);
void add_opt (vec<str> *v, const char *o, const str &s);

template<class T> static void
add_opt (vec<str> *v, const char *o, const T &t)
{
  strbuf b;
  b << t;
  v->push_back (o);
  v->push_back (b);
}

class wkrefcount_t {
public:
  wkrefcount_t () : _alive (New refcounted<bool> (true)) {}
  ~wkrefcount_t () { *_alive = false; }
  ptr<bool> flg () { return _alive; }
private:
  const ptr<bool> _alive;
};

template<class T>
class wkref_t {
public:
  wkref_t (T *p = NULL) : _pointer (p) { if (p) _alive = p->flg ();  }

  operator T * () const { return get (); }
  T *operator-> () const { return get (); }
  T &operator* () const { return *get (); }
  T * get() const { return (_pointer && _alive && *_alive) ? _pointer : NULL; }

  wkref_t<T> &operator= (T *in) 
  { 
    _pointer = in;
    if (in) _alive = in->flg (); 
    else _alive = NULL;
    return *this;
  }

private:
  T *_pointer;
  ptr<bool> _alive;
};

// return code set -- simplifies return code management for
// multiple outstanding label operations

template<class T>
class rcset_t : public vec<T>
{
public:
  rcset_t (size_t s, const T &ok) : vec<T> (), _ok (ok)
  { 
    setsize (s);
  }

  rcset_t (const T &ok) : vec<T> (), _ok (ok) {}

  void setsize (size_t s) 
  {
    vec<T>::setsize (s); 
    for (size_t i = 0; i < s; i++) {
      (*this)[i] = _ok;
    }
  }
    
  T project () const
  {
    T rc = _ok;
    for (size_t i = 0; rc == _ok && i < this->size (); i++) 
      if ((*this)[i] != rc)
	rc = (*this)[i];
    return rc;
  }
private:
  const T _ok;
};

void init_clock ();

template<class T> str
rpc_enum_to_str (const T &t)
{
  strbuf b;
  rpc_print (b, t);
  str s = b;
  if (s[s.len() - 1] == '\n')
    s = substr (s, 0, s.len () - 1);
  return s;
}

int flmsockopt (int fd);

#endif /* _LIBFLUME_ASYNCUTIL_H_ */
