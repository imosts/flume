// -*-c++-*-
// 
// Use C++ mode since it's better than nothing!

%module flume_internal

%{

extern "C" {
#include <fcntl.h>
#include "flume_features.h"
#include "flume_debug.h"
#include "flume_const.h"
#include "flume_prot.h"
#include "flume_api.h"
#include "flume_clnt.h"
}

#include "flume_i_ops.h"
%}


%constant int HANDLE_OPT_PERSISTENT = HANDLE_OPT_PERSISTENT;

typedef unsigned int u_int;
typedef unsigned long long x_handle_t;
typedef int handle_prefix_t;
typedef int flume_status_t;
typedef int label_type_t;
typedef int setcmp_type_t;
typedef int mode_t;
typedef int frozen_label_typ_t;

%constant int HANDLE_OPT_PERSISTENT = HANDLE_OPT_PERSISTENT;
%constant int HANDLE_OPT_GROUP = HANDLE_OPT_GROUP;
%constant int HANDLE_OPT_DEFAULT_ADD = HANDLE_OPT_DEFAULT_ADD;
%constant int HANDLE_OPT_DEFAULT_SUBTRACT = HANDLE_OPT_DEFAULT_SUBTRACT;
%constant int HANDLE_OPT_IDENTIFIER = HANDLE_OPT_IDENTIFIER;

%constant int DUPLEX_FULL = DUPLEX_FULL;
%constant int DUPLEX_THEM_TO_ME = DUPLEX_THEM_TO_ME;
%constant int DUPLEX_ME_TO_THEM = DUPLEX_ME_TO_THEM;

%constant int O_RDONLY = O_RDONLY;
%constant int O_WRONLY = O_WRONLY;
%constant int O_RDWR = O_RDWR;
%constant int O_APPEND = O_APPEND;
%constant int O_CREAT = O_CREAT;
%constant int O_TRUNC = O_TRUNC;
%constant int O_EXCL = O_EXCL;

%constant int CAPABILITY_ADD = CAPABILITY_ADD;
%constant int CAPABILITY_SUBTRACT = CAPABILITY_SUBTRACT;
%constant int CAPABILITY_GROUP_SELECT = CAPABILITY_GROUP_SELECT;

%constant int SPAWN_SETUID = SPAWN_SETUID;
%constant int SPAWN_CONFINED = SPAWN_CONFINED;

%constant int SPAWN_OK = SPAWN_OK;
%constant int SPAWN_DISAPPEARED = SPAWN_DISAPPEARED;

%constant int FROZEN_LABEL_BASE16 = FROZEN_LABEL_BASE16;
%constant int FROZEN_LABEL_BASE32 = FROZEN_LABEL_BASE32;
%constant int FROZEN_LABEL_BINARY = FROZEN_LABEL_BINARY;

%constant int COMPARE_NONE = COMPARE_NONE;
%constant int COMPARE_SUBTRACT = COMPARE_SUBTRACT;
%constant int COMPARE_ADD = COMPARE_ADD;

%constant int FLUME_OK = FLUME_OK;
%constant int FLUME_ENOMEM = FLUME_EMEM;
%constant int FLUME_ENULL = FLUME_ENULL;
%constant int FLUME_EPERM = FLUME_EPERM;
%constant int FLUME_EINVAL = FLUME_EINVAL;
%constant int FLUME_ERANGE = FLUME_ERANGE;
%constant int FLUME_ENOENT = FLUME_ENOENT;
%constant int FLUME_EROFS = FLUME_EROFS;
%constant int FLUME_ECAPABILITY = FLUME_ECAPABILITY;
%constant int FLUME_EEXIST = FLUME_EEXIST;
%constant int FLUME_EEXPIRED = FLUME_EEXPIRED;
%constant int FLUME_EHANDLE = FLUME_EHANDLE;
%constant int FLUME_EATTR = FLUME_EATTR;
%constant int FLUME_EPERSISTENCE = FLUME_EPERSISTENCE;
%constant int FLUME_EXDR = FLUME_EXDR;

%constant int LABEL_NONE = LABEL_NONE;
%constant int LABEL_S = LABEL_S;
%constant int LABEL_I = LABEL_I;
%constant int LABEL_O = LABEL_O;
%constant int LABEL_NO_O = LABEL_NO_O;
%constant int LABEL_ALL = LABEL_ALL;

%constant int CAPABILITY_GRANT = CAPABILITY_GRANT;
%constant int CAPABILITY_SHOW = CAPABILITY_SHOW;
%constant int CAPABILITY_VERIFY = CAPABILITY_VERIFY;
%constant int CAPABILITY_TAKE = CAPABILITY_TAKE;
%constant int CAPABILITY_CLEAN = CAPABILITY_CLEAN;

%constant int FLUME_EP_OPT_STRICT = FLUME_EP_OPT_STRICT;
%constant int FLUME_EP_OPT_FIX = FLUME_EP_OPT_FIX;

%newobject _LabelSet::_get_S ();
%newobject _LabelSet::_get_I ();
%newobject _LabelSet::_get_O ();
%newobject _Endpoint::_get_S ();
%newobject _Endpoint::_get_I ();
%newojbect _Filter::find ();
%newojbect _Filter::replace ();
%newobject _LabelChange::_get_label () const;
%newobject _LabelChange::_clone () const;

%newobject _new_handle(int opts, const char *name);
%newobject _new_group(const char *name, _LabelSet *ls);
%newobject _get_label (label_typ_t typ);
%newobject _get_endpoint_info (void);
%newobject _get_labelset (void);
%newobject _get_fd_label (label_typ_t typ, int fd);
%newobject _stat_group (_Handle *);
%apply (char *STRING, int LENGTH) { (char *str, int len) };
%newobject _Label_freeze (const _Label *l);
%newobject _thaw_handle (const _Handle *);
%newobject _Handle::armor32 () const;
%newobject _RawData::armor32 () const;
%newobject _LabelSet::_to_raw (void) const;
%newobject _Handle::_to_raw (void) const;
%newobject _CapabilityOp::_get_h ();
%newobject _dearmor_token (char *in);
%newobject _lookup_by_nickname ( const char *in );
%newobject _Handle::_to_capability (int opt) const;
%newobject random_str (int i);
%newobject _LabelSet::_to_filename () const;
%newobject _make_login (const _Handle *in, u_int dur, bool fixed);
%newobject _setuid_handle();
%newobject _spawn (const char *cmd, const _Argv *argv, const _Argv *env,
		   int opts, const _Label *claim, 
		   const _LabelChangeSet *lchanges, const _Label *I_min, 
		   const _Endpoint *endpoint);

%newobject _FlumePair::gethandle () const;
%newobject _WaitResult::_get_pid () const;
		   
%newobject _socketpair (int duplex_mode);

%newobject _LabelChangeSet::_clone () const;
%newobject _EndpointSet::_clone () const;
%newobject _CapabilityOpSet::_clone () const;
%newobject _IntArr::_clone () const;
%newobject _Label::_clone () const;
%newobject _LabelChangeSet::_get (u_int) const;
%newobject _EndpointSet::_get (u_int) const;
%newobject _CapabilityOpSet::_get (u_int) const;
%newobject _Label::get (u_int i) const;
%newobject _IntArr::get (u_int) const;
%newobject _LabelChangeSet::_to_raw (void) const;
%newobject _EndpointSet::_to_raw (void) const;
%newobject _CapabilityOpSet::_to_raw (void) const;
%newobject _IntArr::_to_raw (void) const;
%newobject _Label::_to_raw (void) const;


%inline %{

  class _Int {
  public:
    _Int () : _val (0) {}
    _Int (int i) : _val (i) {}
    ~_Int () {}
    void set (int i) { _val = i; }
    int val () const { return _val; }
    const int *obj () const { return &_val; }
    int *obj () { return &_val; }
  private:
    int _val;
  };

  //-----------------------------------------------------------------------

  class _RawData {
  public:
    
    int _copy (const _RawData *rd)
    {
      return _init (rd->_data, rd->_len);
    }
    
    _RawData () : _data (NULL), _len (0) {}

    int
    _init (const char *str, int len)
    {
      if (!str) {
	FLUME_SET_ERRNO (FLUME_ENULL);
	return -1;
      }
      if (len >= _len) {
	if (_data) delete [] _data;
	_data = new char[len];
	if (!_data) {
	  FLUME_SET_ERRNO (FLUME_EMEM);
	  return -1;
	}
      }
      memcpy (_data, str, len);
      _len = len;
      return 0;
    }

    bool _eq (const _RawData *in) const
    {
      return (in->len () == len () &&
	      memcmp (data (), in->data (), len()) == 0);
    }
    
    const char *data () const { return _data; }
    int len () const { return _len; }
    
    void clear (void)
    {
      if (_data) delete [] _data;
     _len = 0;
    }
    
    char *armor () const
    {
      size_t dummy;
      return armor32_c (static_cast<const void *> (_data), _len, &dummy);
    }
    
    int _dearmor (const char *s)
    {
      size_t len;
      int rc = -1;
      char *r = dearmor32_c (s, strlen (s), &len);
      if (!r) {
	FLUME_SET_ERRNO (FLUME_EINVAL);
      } else {
	_init (r, len);
	rc = 0;
	free (r);
      }
      return rc;
    }
    
    ~_RawData ()  { clear (); }
    
  private:
    char *_data;
    int _len;
  };
  
 //-----------------------------------------------------------------------
 
 template<class T> _RawData *
   __to_raw (typename raw_ops_t<T>::to_static_t fn, const T *obj)
 {
   _RawData *ret = NULL;
   char buf[XDR_MAXSZ];
   if (!obj) {
     FLUME_SET_ERRNO (FLUME_ENULL);
   } else {
     ssize_t sz = fn (buf, XDR_MAXSZ, obj);
      if (sz > 0) {
	ret = new _RawData ();
	if (ret->_init (buf, sz) < 0) {
	  delete ret;
	  ret = NULL;
	}
      }
   }
   return ret;
 }

 //-----------------------------------------------------------------------

 template<class T> int
   __from_raw (typename raw_ops_t<T>::from_t fn, T *obj, const _RawData *in)
 {
   return fn (obj, in->data (), in->len ());
 }

 //-----------------------------------------------------------------------

class _Handle {
public:
  _Handle () : _val (0), _name (NULL) {}
  _Handle (x_handle_t val, const char *name) 
    : _val (val), _name (name ? strdup(name) : NULL) {}
  
  ~_Handle () 
  { 
    FLUME_DEBUG (FLUME_DEBUG_MEMORY, stderr, "~_Handle() called...\n");
    if (_name) free (_name); 
  }

  int _init (x_handle_t val, const char *name)
  {
    _val = val;
    if (_name) free (_name);
    _name = name ? strdup (name) : NULL;
    return -1;
  }
  
  _RawData *_to_raw (void) const
  { return __to_raw<x_handle_t> (handle_to_raw_static, &_val); }
  int _from_raw (const _RawData *in)
  { return __from_raw<x_handle_t> (handle_from_raw, &_val, in); }
  
  static x_handle_t mk (handle_prefix_t prfx, x_handle_t base)
  { return handle_construct (prfx, base); }
  
  int prefix () const { return handle_prefix (_val); }
  x_handle_t base () const { return handle_base (_val); }
  x_handle_t val () const { return _val; }
  const char *name () const { return _name; }
  void set (x_handle_t i) { _val = i; }
  const x_handle_t *obj() const { return &_val; }
  x_handle_t *obj() { return &_val; }
  
  _Handle *_to_capability (int opt) const
  {
    return new _Handle (capability_construct (opt, _val), _name);
  }
  
  char *armor32 () const
  {
    size_t dummy;
    return armor32_c (static_cast<const void *> (&_val), 
		      sizeof (_val), &dummy);
  }
  
  int _dearmor32 (const char *s)
  {
    size_t len;
    int rc = -1;
    char *r = dearmor32_c (s, strlen (s), &len);
    
    if (!r || len != sizeof (_val)) {
      FLUME_SET_ERRNO_STR (FLUME_EHANDLE, s);
    } else {
      rc = 0;
      memcpy (&_val, r, len);
    }
    if (r) free (r);
    return rc;
  }
  
private:
  x_handle_t _val;
  char *_name;
};

class _Argv {
public:
  _Argv (int sz) 
  {
    if (sz >= 0) {
      _sz = sz + 1;
      _dat = new (char *[_sz]);
      memset (_dat, 0, _sz * sizeof (char *));
    } else {
      _sz = 0;
      _dat = NULL;
    }
  }

  int _set (u_int i, char *c) 
  {
    if (i >= (_sz - 1)) {
      FLUME_SET_ERRNO (FLUME_ERANGE);
      return -1;
    }
    if (_dat[i]) 
      free (_dat[i]);
    _dat[i] = strdup (c);
    return 0;
  }

  ~_Argv ()
  {
    if (_dat) {
      for (u_int i = 0; i < _sz; i++) {
	if (_dat[i]) 
	  free (_dat[i]);
      }
      delete [] _dat;
    }
  }

  char *_get (u_int i) { 
    if (i >= _sz) return NULL;
    return _dat[i];
  }
  
  char **dat () { return _dat; }
  char *const *dat_const () const { return _dat; }

private:
  u_int _sz;
  char **_dat;
};

 class _LabelVec;
 class _Filter;
 class _LabelChange;
 
 //-----------------------------------------------------------------------

 //
 // * Class T = the C type of foo_set
 // * Class E = the C type of foo
 // * Class EW = the C++/swig type of the wrapper around foo.
 //
 template<class T, class E, class EW>
 class _ObjSetWrapper {
 public:
   _ObjSetWrapper ()
     : _ops (alloc_set_obj_ops<T,E> ()), 
       _name (_ops.prfx), 
       _obj (_ops.allocfn(0)) {}
   
   ~_ObjSetWrapper ()
   {
     FLUME_DEBUG (FLUME_DEBUG_MEMORY, stderr, "~_%s() called..\n", _name);
     _ops.freefn (_obj);
   }
   
   _ObjSetWrapper<T,E,EW> *_clone () const 
   { return _ObjSetWrapper<T,E,EW>::_alloc (_obj); }

   u_int _size () const { return _ops.sizefn (_obj); }
   int _resize (u_int sz) { return _ops.resizefn (_obj, sz, 1); }
   void _clear () { return _ops.clearfn (_obj); }
   T *obj () { return _obj; }
   const T *obj () const { return _obj; }
   
   int _copy (const _ObjSetWrapper<T,E,EW> *in)
   {
     int rc = 0;
     if (!in) {
       FLUME_SET_ERRNO(FLUME_NULL);
       rc = -1;
     } else if (!in->obj ()) {
       _clear ();
     } else {
       rc = _ops.copyfn (_obj, in->obj ());
     }
     return rc;
   }
   
   _RawData *_to_raw (void) const { return __to_raw<T> (_ops.torawfn, _obj); }
   int _from_raw (const _RawData *in) 
   { return __from_raw<T> (_ops.fromrawfn, _obj, in); }
   
   int _set (u_int i, const EW *w)
   {
     E *curr;
     int rc = -1;
     if (!w) {
       FLUME_SET_ERRNO(FLUME_ENULL);
     } else {
       if ((curr = _ops.getpfn (_obj, i))) {
	 _ops.obj_clearfn (curr);
	 _ops.obj_copyfn (curr, w->obj());
	 rc = 0;
       }
     }
     return rc;
   }
   
   EW *_get (u_int i) const
   {
     E *o = _ops.getpfn (_obj, i);
     EW *r = NULL;
     if (o) {
       if (!(r = new EW ())) {
	 FLUME_SET_ERRNO (FLUME_EMEM);
       } else {
	 if (_ops.obj_copyfn (r->obj (), o) < 0) {
	   delete r;
	   r = NULL;
	 }
       }
     }
     return r;
   }

   static _ObjSetWrapper<T,E,EW> *_alloc (T *o)
   {
     _ObjSetWrapper<T,E,EW> *ret = new _ObjSetWrapper<T,E,EW> ();
     if (ret && ret->_ops.copyfn (ret->obj (), o) < 0) {
       delete ret;
       ret = NULL;
     }
     return ret;
   }

 private:
   
   set_obj_ops_t<T,E> _ops;
   const char *_name;
   T * _obj;
 };

 //-----------------------------------------------------------------------

 typedef _ObjSetWrapper<x_label_t, u_int64_t, _Handle> _Label;

 //-----------------------------------------------------------------------

 typedef _ObjSetWrapper<x_int_set_t, int, _Int> _IntArr;

 //-----------------------------------------------------------------------
 
 class _LabelVec {
 public:
   _LabelVec (int len) 
     : _data (new x_label_t[len]), 
       _len (len)
   {
     for (int k = 0; k < len; k++) {
       label_init (_data + k);
     }
   }

   ~_LabelVec () 
   { 
     for (int k = 0; k < _len; k++) {
       label_clear (_data + k);
     }
     delete [] _data; 
   }
   
   int _set (int pos, const _Label *in)
   {
     if (pos < 0 || pos >= _len) {
       FLUME_SET_ERRNO (FLUME_ERANGE);
       return -1;
     }
     if (in->obj ()) {
       label_copy (_data + pos, in->obj ()); 
     } else {
       label_clear (_data + pos);
     }
     return 0;

   }

   const x_label_t *get_data (int *len) const
   {
     *len = _len;
     return _data;
   }
   
 private:
   x_label_t *_data;
   int _len;
 };

 class _Token {
 public:
   _Token (char *str, int len) 
   {
     _init (str, len);
   }

   void _init (char *s, int len)
   {
     int capacity = sizeof (_tok);
     if (len > capacity) len = capacity;
     _tok.typ = PRIV_TOK_BINARY;
     memset (_tok.u.bintok.val, 0, capacity);
     if (s && len >= 0) {
       memcpy (_tok.u.bintok.val, s, len);
     } 
   }

   int _dearmor (const char *s) 
   {
     size_t len;
     int rc = -1;
     char *r = dearmor32_c (s, strlen (s), &len);
     if (!r) {
       FLUME_SET_ERRNO (FLUME_EINVAL);
     } else {
       _init (r, len);
       rc = 0;
       free (r);
     }
     return rc;
   }

   ~_Token () {}
   char *buf () { return _tok.u.bintok.val; }
   priv_tok_t *obj () { return &_tok; }
   const priv_tok_t *obj () const { return &_tok; }
   
 private:
   priv_tok_t _tok;
 };

 //-----------------------------------------------------------------------

 class _Filter {
 public:
   _Filter () : _obj (filter_alloc ()) {}
   ~_Filter () { filter_free (_obj); }
   
   int copy (const _Filter *in)
   {
     int rc = 0;
     if (!in) {
       FLUME_SET_ERRNO (FLUME_ENULL);
       rc = -1;
     } else {
       filter_copy (_obj, in->obj ());
     }
     return rc;
   }
   
   _Label *find () { return _Label::_alloc (&_obj->find); }
   _Label *replace () { return _Label::_alloc (&_obj->replace); }
   
   x_filter_t *obj () { return _obj; }
   const x_filter_t *obj () const { return _obj; }
   
 private:
   x_filter_t *_obj;
 };

 //-----------------------------------------------------------------------
 
 class _LabelSet {
 public:
   _LabelSet () : _obj (labelset_alloc ()) {}
   ~_LabelSet () { labelset_free (_obj); }
   
   x_labelset_t *obj () { return _obj; }
   const x_labelset_t *obj () const { return _obj; }
   
   int _set_S (_Label *l) 
   { 
     return labelset_set_S (_obj, l ? l->obj () : NULL);
   }
   
   int _set_I (_Label *l)
   {
     return labelset_set_I (_obj, l ? l->obj () : NULL);
   }
   
   int _set_O (_Label *l)
   {
     return labelset_set_O (_obj, l ? l->obj () : NULL);
   }
   
   _Label *_get_S () { return _Label::_alloc (labelset_get_S (_obj)); }
   _Label *_get_I () { return _Label::_alloc (labelset_get_I (_obj)); }
   _Label *_get_O () { return _Label::_alloc (labelset_get_O (_obj)); }


   _RawData *_to_raw (void) const 
   { return __to_raw<x_labelset_t> (labelset_to_raw_static, _obj); }

   int _from_raw (const _RawData *in) 
   { return __from_raw<x_labelset_t> (labelset_from_raw, _obj, in); }

   char *_to_filename () const
   { return flume_labelset_to_filename (_obj); }

   int copy (const _LabelSet *in)
   {
     int rc = 0;
     if (!in) {
       FLUME_SET_ERRNO (FLUME_ENULL);
       rc = -1;
     } else {
       rc = labelset_copy (_obj, in->obj ());
     }
     return rc;
   }

   int alloc_O (u_int sz) { return labelset_alloc_O (_obj, sz); }

 private:
   x_labelset_t *_obj;
 };

 //-----------------------------------------------------------------------
 
 class _LabelChange {
 public:
   _LabelChange() : _obj (label_change_alloc ()) {}
   ~_LabelChange () { label_change_free (_obj); }
   x_label_change_t *obj () { return _obj; }
   const x_label_change_t *obj () const { return _obj; }

   int _copy (const _LabelChange *in)
   {
     int rc = 0;
     if (!in) {
       FLUME_SET_ERRNO (FLUME_ENULL);
       rc = -1;
     } else {
       rc = label_change_copy (_obj, in->obj ());
     }
     return rc;
   }

   _LabelChange * _clone () const
   {
     x_label_change_t *x = label_change_clone (_obj);
     _LabelChange *ret = NULL;
     if (x) {
       ret = new _LabelChange (x);
     }
     return ret;
   }

   int get_which () const { return label_change_get_which (_obj); }
   int set_which (int i) { return label_change_set_which (_obj, i); }

   int _set_label (const _Label *l) 
   {
     return label_change_set_label (_obj, l ? l->obj () : NULL);
   }
   
   _Label *_get_label ()
   {
     return _Label::_alloc (label_change_get_label (_obj)); 
   }

 private:
   _LabelChange (x_label_change_t *x) : _obj (x) {}
   x_label_change_t *_obj;
 }; 

 //-----------------------------------------------------------------------

 class _Endpoint {
 public:
   _Endpoint() : _obj (endpoint_alloc ()) {}
   ~_Endpoint () { endpoint_free (_obj); }

   x_endpoint_t *obj () { return _obj ;}
   const x_endpoint_t *obj() const { return _obj; }

   int _set_S (_Label *l)
   {
     return endpoint_set_S (_obj, l ? l->obj () : NULL);
   }

   int _set_I (_Label *l)
   {
     return endpoint_set_I (_obj, l ? l->obj () : NULL);
   }

   int copy (const _Endpoint *in)
   {
     int rc = 0;
     if (!in) { 
       FLUME_SET_ERRNO (FLUME_ENULL);
       rc = -1;
     } else {
       rc = endpoint_copy (_obj, in->obj ());
     }
     return rc;
   }

   _Label *_get_S () { return _Label::_alloc (endpoint_get_S (_obj)); }
   _Label *_get_I () { return _Label::_alloc (endpoint_get_I (_obj)); }

   const char *_get_desc () const 
   { return _obj ? endpoint_get_desc (_obj) : NULL; }

   u_int _get_readable () const { return _attr_get (EP_READ); }
   u_int _get_writable () const { return _attr_get (EP_WRITE); }
   u_int _get_mutable () const { return _attr_get (EP_MUTABLE); }

   void _set_mutable (int v) { return _attr_set (EP_MUTABLE, v); }
   void _set_writable (int v) { return _attr_set (EP_WRITE, v); }
   void _set_readable (int v) { return _attr_set (EP_READ, v); }

 private:

   void _attr_set (u_int i, int v) 
   {
     u_int a = endpoint_get_attributes (_obj);
     if (v) { a |= i; }
     else { a &= ~i; }
     endpoint_set_attributes (_obj, a);
   }

   u_int _attr_get (u_int i) const 
   { return endpoint_get_attributes (_obj) & i; }

   x_endpoint_t *_obj;
 };

 class _CapabilityOp {
 public:
   _CapabilityOp () {}
   const x_capability_op_t *obj () const { return &_obj; }
   x_capability_op_t *obj () { return &_obj; }
   void _set_h (_Handle *h) { _obj.handle = h ? h->val () : 0ULL; }
   void _set_op (int i) { _obj.level = capability_flag_t (i); } 
   int _get_op () const { return _obj.level; }
   _Handle *_get_h () const { return new _Handle (_obj.handle, "anon cap"); }
 private:
   x_capability_op_t _obj;
 };

 //-----------------------------------------------------------------------

  typedef _ObjSetWrapper<x_label_change_set_t, 
     x_label_change_t, _LabelChange> _LabelChangeSet;
  typedef _ObjSetWrapper<x_capability_op_set_t, 
     x_capability_op_t, _CapabilityOp> _CapabilityOpSet;
  typedef _ObjSetWrapper<x_endpoint_set_t, 
     x_endpoint_t, _Endpoint> _EndpointSet;

  //-----------------------------------------------------------------------

  int _subsetOf (const _Label *l, const _LabelVec *lv, setcmp_type_t t) 
  {
    if (!l || !lv) {
      FLUME_SET_ERRNO (FLUME_ENULL);
      return -1;
    }
    int len;
    const x_label_t *v = lv->get_data (&len);
    
    return flume_subset_of (l->obj (), v, len, t);
  }
   
int _open (const char *path, int flags, int mode, _LabelSet *l,
	   _LabelSet *epl)
{
  return flume_open (path, flags, mode, l ? l->obj () : NULL, 
		    epl ? epl->obj () : NULL);
}

int _symlink (const char *contents, const char *newfile, _LabelSet *l)
{
  return flume_symlink_full (contents, newfile, l ? l->obj () : NULL);
}

int _writefile (const char *path, int flags, int mode, _LabelSet *l,
		char *str, int len)
{
  const x_labelset_t *c = NULL;
  if (l) {
    c = l->obj ();
  }
    
  return flume_writefile (path, flags, mode, c, str, len);
}


_Handle *_new_handle (int opts, const char *name) 
{
  x_handle_t tc;
  _Handle *r = NULL;
  int rc = flume_new_handle (&tc, opts, name);
  if (rc == 0) {
    if (!(r = new _Handle (tc, name))) {
      FLUME_SET_ERRNO (FLUME_EMEM);
    }
  }
  return r;
}

_EndpointSet *
_get_endpoint_info (void)
{
  _EndpointSet *ret = new _EndpointSet ();
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else {
    if (flume_get_endpoint_info (ret->obj ()) < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

_LabelSet *
_get_labelset (void)
{
  _LabelSet *ret = new _LabelSet ();
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else {
    if (flume_get_labelset (ret->obj ()) < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

_Label *
_get_label (label_type_t typ)
{
  _Label *ret = new _Label ();
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else {
    if (flume_get_label (ret->obj (), typ) < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

_Label *
_get_fd_label (label_type_t typ, int fd)
{
  _Label *ret = new _Label ();
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else {
    if (flume_get_fd_label (ret->obj (), typ, fd) < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

int
_set_fd_label (label_type_t typ, int fd, const _Label *in)
{
  const x_label_t *l = NULL;
  if (in) l = in->obj ();
  return flume_set_fd_label (l, typ, fd);
}

int
_set_label (label_type_t typ, const _Label *in, bool frc)
{
  const x_label_t *l = NULL;
  if (in) l = in->obj ();
  return flume_set_label (l, typ, frc);
}

_Handle *
_setuid_handle ()
{
  x_handle_t tc;
  int rc;
  _Handle *ret = NULL;
  rc = flume_setuid_tag (&tc);
  if (rc == 0) {
    if (!(ret = new _Handle (tc, "setuid")))
      FLUME_SET_ERRNO (FLUME_EMEM);
  }
  return ret;
}

_Handle *
_new_group (const char *name, _LabelSet *lso)
{
  x_handle_t tc;
  _Handle *res = NULL;
  int rc;
  x_labelset_t *ls = NULL;
  if (lso) 
    ls = lso->obj ();
  rc = flume_new_group (&tc, name, ls);
  if (rc == 0) {
    if (!(res = new _Handle (tc, name))) {
      FLUME_SET_ERRNO (FLUME_EMEM);
    }
  }
  return res;
}

_Handle *
_lookup_by_nickname (const char *nm)
{
  x_handle_t tmp;
  _Handle *res = NULL;
  int rc;
  if ((rc = flume_lookup_by_nickname (&tmp, nm)) == 0) {
    if (!(res = new _Handle (tmp, nm))) {
      FLUME_SET_ERRNO (FLUME_EMEM);
    }
  }
  return res;
}

_LabelSet *
_stat_group (_Handle *h)
{
  int rc;
  _LabelSet *ret = NULL;
  if (!h) {
    rc = -1;
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    if (!(ret = new _LabelSet ())) {
      FLUME_SET_ERRNO (FLUME_EMEM); 
    } else if ((rc = flume_stat_group (ret->obj (), h->val ())) < 0) {
      delete ret;      
    }
  }
  return ret;
}

_LabelSet *
_stat_file (const char *fn)
{
  int rc;
  _LabelSet *ret = NULL;
  if (!fn) {
   rc = -1;
   FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    if (!(ret = new _LabelSet ())) {
      FLUME_SET_ERRNO (FLUME_EMEM);
    } else if ((rc = flume_stat_file (ret->obj (), fn)) < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

int
_unlink (const char *fn)
{
  int rc;
  if (!fn) {
    rc = -1;
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    rc = flume_unlink (fn);
  }
  return rc;
}

int
_listen (int fd, int queue_len)
{
  return flume_listen (fd, queue_len);
}

int
_accept (int fd)
{
  return flume_accept (fd);
}

int 
_unixsocket_connect (const char *path)
{
  return flume_unixsocket_connect_c (path);
}

int
_unixsocket (const char *path, _LabelSet *ls)
{
  x_labelset_t *tc = ls ? ls->obj () : NULL;
  return flume_unixsocket (path, tc);
}

int
_add_to_group (_Handle *h, _Label *l)
{
  int rc;
  if (!h || !l) {
    rc = -1;
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    rc = flume_add_to_group (h->val (), l->obj ());
  }
  return rc;
}

int
_mkdir (const char *path, mode_t mode, _LabelSet *ls)
{
  x_labelset_t *tc = ls ? ls->obj () : NULL;
  return flume_mkdir_full (path, mode, tc);
}

char *
_make_login (const _Handle *in, u_int dur, bool fixed)
{
  int rc = 0;
  char *tok = NULL;
  if (in) {
    rc = flume_make_login (in->val (), dur, fixed, &tok);
  } else {
    rc = -1;
    FLUME_SET_ERRNO (FLUME_ENULL);
  }
  return tok;
}

int
_req_privs (const _Handle *in, const char *tok)
{
  int rc = -1;
  if (!in || !tok) {
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    rc = flume_req_privs (in->val (), tok);
  }
  return rc;
}

int
_make_nickname (const _Handle *in, const char *name)
{
  int rc = -1;
  if (!in) {
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    rc = flume_make_nickname (in->val (), name);
  }
  return rc;
}

_Token *
_dearmor_token (const char *in)
{
  _Token *ret = new _Token (NULL, 0);
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else if (ret->_dearmor (in) < 0) {
    delete ret;
    ret = NULL;
  }
  return ret;
}

int get_errno () { return flume_get_flm_errno (); }
const char *get_errstr () { return flume_get_errstr(); }

char *random_str (int i)
{
  return flume_random_str (i);
}

_Label *_thaw_handle (const _Handle *h) 
{
  _Label *ret = new _Label ();
  x_handle_t val = h->val ();
  int rc = flume_thaw_label (ret->obj (), &val);
  if (rc < 0) {
    delete ret;
    ret = NULL;
  }
  return ret;
}

class _FlumePair {
public:
  _FlumePair (int fd, x_handle_t h) : _fd (fd), _handle (h) {}
  ~_FlumePair () {}

  int getfd () const { return _fd; }
  _Handle *gethandle () { return new _Handle (_handle, "socketpair end"); }

private:
  int _fd;
  x_handle_t _handle;
};

class _WaitResult {
public:
  _WaitResult (int v, int ec, x_handle_t x) 
    : _visible (v), _exit_code (ec), _pid (x) {}

  int _get_visible () const { return _visible; }
  int _get_exit_code () const { return _exit_code; }
  _Handle *_get_pid () const { return new _Handle (_pid, "wait result"); }
private:
  int _visible, _exit_code;
  x_handle_t _pid;
};

/*
 * _spawn returns a pair, the first item of which is a int that signifies
 * whether the process is visible to the parent or not.  The second item
 * is just the pid of the new process, in handle form.
 */
_FlumePair *
_spawn (const char *cmd, const _Argv *argv, const _Argv *env,
	int opts, const _Label *claim, const _LabelChangeSet *lchanges,
	const _Label *I_min, const _Endpoint *endpoint,
	const _Endpoint *ch_endpoint)
{
  int rc;
  _FlumePair *ret = NULL;
  x_handle_t tmp;

  const x_handlevec_t *claim_c = NULL;
  const x_label_change_set_t *lchanges_c= NULL;
  const x_label_t *imin_c = NULL;
  const x_endpoint_t *endpoint_c = NULL;
  const x_endpoint_t *ch_endpoint_c = NULL;

  if (!cmd || !argv || !env) {
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    if (claim) claim_c = claim->obj ();
    if (lchanges) lchanges_c = lchanges->obj ();
    if (I_min) imin_c = I_min->obj ();
    if (endpoint) endpoint_c = endpoint->obj ();
    if (ch_endpoint) ch_endpoint_c = ch_endpoint->obj ();

    rc = flume_spawn (&tmp, 
		      cmd, 
		      argv->dat_const (), 
		      env->dat_const (), 
		      opts,
		      claim_c,
		      lchanges_c,
		      imin_c,
		      endpoint_c,
		      ch_endpoint_c);

    if (rc >= 0) {
      if (!(ret = new _FlumePair (rc, tmp))) {
	FLUME_SET_ERRNO (FLUME_EMEM);
      }
    }
  }
  return ret;
}

_FlumePair *
_socketpair (int duplex_mode, const char *desc)
{
  int fd;
  x_handle_t h;
  _FlumePair *ret = NULL;
  if (flume_socketpair (duplex_mode, &fd, &h, desc) == 0) {
    if (!(ret = new _FlumePair (fd, h))) {
      FLUME_SET_ERRNO(FLUME_EMEM);
    }
  }
  return ret;
}

int _claim (const _Handle *h, const char *desc)
{
  int rc = -1;
  if (!h) {
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else {
    rc = flume_claim_socket (h->val (), desc);
  }
  return rc;
}

_WaitResult *
_waitpid (const _Handle *h, int options)
{
  _WaitResult *ret = NULL;

  x_handle_t pidout;
  int visible;
  int ec;

  x_handle_t inpid = 0;
  if (h)
    inpid = h->val ();
  if (flume_waitpid (&pidout, &visible, &ec, inpid, options) == 0) {
    if (!(ret = new _WaitResult (visible, ec, pidout))) {
      FLUME_SET_ERRNO(FLUME_EMEM);
    }
  }
  return ret;
}

_Filter *
_apply_filter (const char *path, label_type_t typ)
{
  _Filter *ret = new _Filter ();
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else {
    int rc = flume_apply_filter (ret->obj (), path, typ);
    if (rc < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

int
_send_capabilities (int fd, const _CapabilityOpSet *o)
{
  int rc = -1;
  if (!o) {
    FLUME_SET_ERRNO(FLUME_NULL);
  } else {
    rc = flume_send_capabilities (fd, o->obj ());
  }
  return rc;
}

int
_flume_fork (const _IntArr *arr, int confined)
{
  int rc = -1;
  if (!arr) {
    FLUME_SET_ERRNO(FLUME_NULL);
  } else {
    rc = flume_fork (arr->obj ()->len, arr->obj ()->val, confined);
  }
  return rc;
}

_CapabilityOpSet *
_verify_capabilities (int fd, int ops_on_all, const _CapabilityOpSet *in)
{
  _CapabilityOpSet *ret = new _CapabilityOpSet ();
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else {
    int rc = flume_verify_capabilities (fd, capability_flag_t (ops_on_all),
					in->obj (), ret->obj ());
    if (rc < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

int
dup_ctl_sock ()
{
  return flume_dup_ctl_sock ();
}

int
_closed_files ()
{
  return flume_closed_files ();
}

int
_set_libc_interposing (int v)
{
  return flume_set_libc_interposing (v);
}

int
_libc_interposing ()
{
  return flume_libc_interposing ();
}

int
_ctl_sock ()
{ 
  return flume_myctlsock ();
}

int
_close (int fd)
{
  return flume_close (fd);
}

int
_flume_null ()
{
  return flume_null ();
}

int
_flume_debug_msg (const char *s)
{
  return flume_debug_msg (s);
}

_LabelSet *
_filename_to_labelset (const char *path)
{
  _LabelSet *ret = new _LabelSet ();
  if (!ret) {
    FLUME_SET_ERRNO (FLUME_EMEM);
  } else {
    if (flume_filename_to_labelset (path, ret->obj ()) < 0) {
      delete ret;
      ret = NULL;
    }
  }
  return ret;
}

int
_setepopt (int fd, int opt, int val)
{
  return flume_setepopt (fd, opt, val);
}


_Handle  *
_Label_freeze (const _Label *in)
{
  _Handle *ret = NULL;
  frozen_label_t tc;
  if (!in->obj ()) {
    FLUME_SET_ERRNO (FLUME_ENULL);
  } else if (flume_freeze_label (&tc, in->obj ()) >= 0) {
    ret = new _Handle (tc, NULL);
  }
  return ret;
}


%}

%template(_LabelChangeSet) 
_ObjSetWrapper<x_label_change_set_t, x_label_change_t, _LabelChange>;
%template(_CapabilityOpSet) 
_ObjSetWrapper<x_capability_op_set_t, x_capability_op_t, _CapabilityOp>;
%template(_EndpointSet) 
_ObjSetWrapper<x_endpoint_set_t, x_endpoint_t, _Endpoint>;
%template(_Label)
_ObjSetWrapper<x_label_t, u_int64_t, _Handle>;
%template(_IntArr)
_ObjSetWrapper<x_int_set_t, int, _Int>;
