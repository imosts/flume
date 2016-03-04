
// -*-c++-*-
#ifndef _LIBFLUME_CACHE_H_
#define _LIBFLUME_CACHE_H_

#include "ihash.h"
#include "list.h"

namespace cache {

  template<class K, class V>
  class obj_t {
  public:
    obj_t (const K &k, const V &v) : _key (k), _value (v) {}

    const K _key;
    V _value;
    ihash_entry<obj_t<K, V> > _hlnk;
    tailq_entry<obj_t<K,V> > _qlnk;
  };

  typedef enum { 
    INSERT_NEW = 0, INSERT_DUP = 1, INSERT_NOSPACE = 2 
  } insert_res_t;
  
  template<class K, class V, class H = hashfn<K>,
	   class E = equals<K> >
  class lru_t {
  public:
    lru_t (ssize_t n) : _max (n), _n (0) {}

    ~lru_t ()
    {
      while (_q.first) {
	remove (_q.first);
      }
    }

    insert_res_t 
    insert (const K &key, const V &val)
    {
      insert_res_t res;
      if (_max < 0) {
	res = INSERT_NOSPACE;
      } else {
	obj_t<K,V> *co = _tab[key];
	if (co) {
	  res = INSERT_DUP;
	  remove (co);
	} else {
	  res = INSERT_NEW;
	}
	_n ++;
	co = New obj_t<K,V> (key, val);
	_tab.insert (co);
	_q.insert_tail (co);
	
	// on insert, need to bump others out.
	purge ();
      }
      return res;
    }

    /*
     * move object to back of LRU queue.
     */
    void
    touch (obj_t<K,V> *o)
    {
      _q.remove (o);
      _q.insert_tail (o);
    }

    /*
     * move object to back of LRU queue
     */
    bool
    touch (const K &k)
    {
      obj_t<K,V> *o = _tab[k];
      if (o) {
	touch (o);
      }
      return o;
    }


    /*
     * fetch an object, optionally 'touching' it.
     */
    V *
    fetch (const K &key, bool dotouch = true)
    {
      if (_max < 0) return NULL;

      obj_t<K,V> *o = _tab[key];
      V *ret = NULL;
      if (o) {
	if (dotouch)
	  touch (o);
	ret = &o->_value;
      }
      return ret;
    }

    V *operator[] (const K &key) { return fetch (key, true); }
    const V *operator[] (const K &key) const { return fetch (key); }

    const V *
    fetch (const K &key) const
    {
      if (_max < 0) return NULL;

      const obj_t<K,V> *o = _tab[key];
      const V *ret = NULL;
      if (o) {
	ret = &o->_value;
      }
      return ret;
    }

    bool 
    remove (const K &key)
    {
      obj_t<K,V> *o = _tab[key];
      if (o) {
	remove (o);
      }
      return o;
    }

    void 
    remove (obj_t<K,V> *o)
    {
      _tab.remove (o);
      _q.remove (o);
      _n--;
      delete (o);
    }

    void
    purge ()
    {
      if (_max > 0) {
	while (_n > _max) {
	  remove (_q.first);
	}
      }
    }
    

  private:
    ihash<const K, obj_t<K,V>, &obj_t<K,V>::_key, &obj_t<K,V>::_hlnk> _tab;
    tailq<obj_t<K,V>, &obj_t<K,V>::_qlnk> _q;

    ssize_t _max, _n;
  };

};




#endif /* _LIBFLUME_CACHE_H_ */
