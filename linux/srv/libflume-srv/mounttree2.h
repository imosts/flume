
// -*-c++-*-

#ifndef _LIBFLUME_MOUNTTREE2_H_
#define _LIBFLUME_MOUNTTREE2_H_

#include "async.h"
#include "list.h"
#include "ihash.h"
#include "rxx.h"
#include "fsutil.h"

namespace mounttree2 {
  
  template<class C>
  class node_t {
  public:
    node_t (const str &s) : _path (s) {}
    str path () const { return _path; }

    str _path;
    qhash<str, ptr<node_t<C> > > _children;
    vec<ptr<C> > _terminals;
  };

  template<class C>
  struct res_t {
    res_t (ptr<C> o, str m, str f) : _obj (o), _mount (m), _file (f) {}
    ptr<C> _obj;
    str _mount, _file;
  };

  template<class C>
  struct iterator_t {
  public:
    iterator_t (const vec<str> &p, ptr<node_t<C> > n)
      : _cur (0), _ok (true)
    {
      str norm_path = fs::flatten (p, true, false);
      if (!norm_path) {
	_ok = false;
	return;
      }

      for (size_t i = 0; n; i++ ) {

	str file;
	for (size_t j = 0; j < n->_terminals.size (); j++) {
	  if (!file) file = substr (norm_path, n->_path.len ());
	  _results.push_back (res_t<C> (n->_terminals[j], n->_path, file));
	}
	ptr<node_t<C> > *np;

	if (i < p.size () && (np = n->_children[p[i]])) {
	  n = *np;
	} else {
	  n = NULL;
	}
      }
    }
      
    
    ptr<C> next (str *mount, str *file)
    {
      if (_cur >= _results.size ()) return NULL;
      *mount = _results[_cur]._mount;
      *file =  _results[_cur]._file;
      return _results[_cur++]._obj;
    }
    bool ok () const { return _ok; }

  private:
    size_t _cur;
    bool _ok;
    vec<res_t<C> > _results;
  };

  template<class C> 
  class root_t {
  public:
    root_t () : _root (New refcounted<node_t<C> > ("/")) {}
    bool insert (const str &s, ptr<C> o)
    {
      ptr<node_t<C> > nxt, *nxtp, p;

      p = _root;
      vec<str> path;
      str np;
      if (!fs::path_split (&path, &np, s)) return false;
      
      str e;

      strbuf b;
      b.cat (p->path(), true);
      
      bool first = true;
      
      for ( ; path.size (); p = nxt) {
	e = path.pop_front ();
	
	if (!first) b << "/";
	else first = false;
	
	b.cat (e, true);
	
	nxtp = p->_children[e];
	if (nxtp) {
	  nxt = *nxtp;
	} else {
	  ptr<node_t<C> > nn = New refcounted<node_t<C> > (b);
	  p->_children.insert (e, nn);
	  nxt = nn;
	}
      }
      p->_terminals.push_back (o);
      return true;
    }

    ptr<iterator_t<C> > mk_iterator (const vec<str> &s)
    {
      ptr<iterator_t<C> > r = New refcounted<iterator_t<C> > (s, _root);
      if (r->ok ()) return r;
      else return NULL;
    }

  private:
    ptr<node_t<C> > _root;
  };

};

#endif /* _LIBFLUME_MOUNTTREE2_H */
