
// -*-c++-*-

#include "flume_features.h"
#include "flume_ev.h"
#include "flume_prot.h"
#include "flume_bf60.h"
//两个hash.h文件找不到
#include "ihash.h"
#include "qhash.h"
#include "tame.h"
#include "keyfunc.h"

#ifndef _FLUME_EV_LABELS_H_
#define _FLUME_EV_LABELS_H_

typedef callback<void, flume_status_t>::ref flume_status_cb_t; 
str status2str (flume_status_t st);

bool is_persistent (handle_prefix_t p);
bool is_valid (handle_prefix_t p);
str prefix2str (handle_prefix_t p);
bool is_group (handle_prefix_t p);
bool is_default_subtract (handle_prefix_t p);
bool is_default_add (handle_prefix_t p);
bool is_capability (handle_prefix_t p);
bool is_identifier (handle_prefix_t p);

const char *labeltyp2str (label_type_t typ);

typedef enum { ARMOR_16, ARMOR_32, ARMOR_32_0, ARMOR_32_NIL } armor_type_t;


class label_t;

enum { CAPABILITY_BITS = CAPABILITY_GROUP_SELECT,
       CAPABILITY_GENERIC = CAPABILITY_GROUP_SELECT };

const char *set_repr (setcmp_type_t typ);

class handle_t {
public:
  handle_t () : _value (0) {}
  handle_t (handle_prefix_t t, u_int64_t bv) 
    : _value (shift (t) | (mask (bv))) {}
  
  handle_t (u_int64_t v) : _value (v) {}
  operator u_int64_t () const { return _value; }
  
  str to_str (armor_type_t typ = ARMOR_16) const;
  bool from_str (const str &s);

//unshift()函数？？？ 
  handle_prefix_t type () const { return unshift (_value); }
  handle_prefix_t prefix () const { return type (); }
  u_int64_t basevalue () const { return mask (_value); }
  inline u_int64_t value () const { return _value; }

  void to_xdr (x_handle_t *x) const { *x = value (); }

  bool operator== (const handle_t &h) const { return _value == h.value (); }
  bool operator!= (const handle_t &h) const { return _value != h.value (); }


  //此处const 和 ::
  bool is_group () const { return ::is_group (type ()); }
  bool is_persistent () const { return ::is_persistent (type ()); }
  bool is_valid () const { return ::is_valid (type()); }
  bool is_identifier () const { return ::is_identifier (type ()); }

//此函数体为空？？？
  bool contained_in (const label_t **rhs, handle_prefix_t cp) const;

  handle_t add_persistence () const 
  { return add_opts (HANDLE_OPT_PERSISTENT); }

  bool is_default_add () { return ::is_default_add (type ()); }
  bool is_default_subtract () { return ::is_default_subtract (type ()); }

  void add_capabilities (label_t *O);

  bool is_flat_handle () const 
  { return ! (type () & (HANDLE_OPT_GROUP|HANDLE_OPT_IDENTIFIER)); }

  bool is_capability () const { return ::is_capability (type ()); }

  handle_t decap () const { return subtract_opts (CAPABILITY_BITS); }

  static handle_t frozen_empty () { return handle_t (0, 0); }

  hash_t hsh () const { return (_value >> 32) ^ (_value & 0xffffffff); }

  static u_int64_t _def_setuid_base;
  static handle_t def_setuid_h ();

protected:
  
  enum { shift_bits = HANDLE_SHIFT_BITS };

  handle_t subtract_opts (handle_prefix_t p) const
  { return handle_t (_value & ( ~ shift (p))); }
  handle_t add_opts (handle_prefix_t p) const
  { return handle_t (_value | shift (p)); }
  static inline u_int64_t shift (handle_prefix_t p) 
  { return (u_int64_t (p) << shift_bits); }
  static inline handle_prefix_t unshift (u_int64_t v) 
  { return handle_prefix_t (v >> shift_bits); }
  static inline u_int64_t mask (u_int64_t in) 
  { return in & HANDLE_MASK; }

private:
  u_int64_t _value;
};

class capability_t : public handle_t {
public:
  capability_t (handle_prefix_t p, handle_t h) : 
    handle_t ((p & CAPABILITY_BITS) | h.prefix (), h.value ()) {}
  capability_t (handle_t h) : handle_t (h) {}
  capability_t () : handle_t () {}
};

struct handle_id_t {
  handle_id_t (handle_prefix_t p) 
    : _prefix (p), _hsh (0), _is_cap (is_capability (_prefix)) {}
  handle_id_t (handle_prefix_t p, str n) : 
    _prefix (p), _name (n), _hsh (mkhsh ()), 
    _is_cap (is_capability (_prefix)) {}

  handle_id_t (const new_handle_arg_t &x) :
    _prefix (x.prefix), _name (x.name), _hsh (mkhsh()),
    _is_cap (is_capability (_prefix)) {}
    
  handle_id_t (bool cap = false) : _hsh (0), _is_cap (cap) {}

  handle_prefix_t prefix () const { return _prefix; }
  str name () const { return _name; }

  handle_id_t decap () const 
  { return handle_id_t (_prefix & ~CAPABILITY_BITS, _name); }

  str to_str () const;
  bool from_str (const str &s);
  void to_xdr (new_handle_arg_t *x) const;

  bool anonymous () const { return !_name || _name.len () == 0; }
  
  bool operator== (const handle_id_t &h) const
  { return _prefix == h._prefix && _name == h._name; }
  
  operator hash_t () const { return _hsh; }
  hash_t mkhsh () const;
  
  handle_prefix_t _prefix;
  str _name;
  hash_t _hsh;
  bool _is_cap;
};

class handle_factory_t {
public:
  virtual ~handle_factory_t () {}

  handle_t newh (handle_prefix_t p, bool no_handle_val_dups = true);
  handle_t newh ();

  void remote_alloc (handle_t h);

  virtual void set_max_id (int64_t i) = 0;
  static void init (const str &seed);
  static handle_factory_t *alloc (const str &s = NULL);
protected:
  bhash<u_int64_t> _already_seen;
  virtual handle_t _newh (handle_prefix_t p) = 0;
  handle_t _newh_reliable (handle_prefix_t p);
};

class handle_factory_secure_t : public handle_factory_t {
public:
  handle_factory_secure_t (const str &seed);
  handle_t _newh (handle_prefix_t p);
  void set_max_id (int64_t i) {}
private:
  u_int64_t _i;
  bf_ctx _ctx;
};

class handle_factory_debug_t : public handle_factory_t {
public:

  // Needs to be 1 greater than def_setuid_h, which is defined
  // as 1
  handle_factory_debug_t () : _i (handle_t::_def_setuid_base) {}
  handle_t _newh (handle_prefix_t p) { return handle_t (p, _i++); }
  void set_max_id (int64_t i) { _i = i + 1;}
private:
  u_int64_t _i;
};

extern handle_factory_t *hfact;

template<> struct hashfn<handle_t> {
  hashfn () {}
  hash_t operator() (const handle_t &h) const 
  {
    return hash_bytes (reinterpret_cast<const void *> (&h), sizeof (h));
  }
};

template<> struct equals<handle_t> {
  equals () {}
  bool operator() (const handle_t &h1, const handle_t &h2) const 
  { return h1 == h2; }
};

typedef qhash_slot<handle_t, void> hset_slot_t;
typedef bhash<handle_t> hset_t;

class hset_iterator_t {
public:
  hset_iterator_t (const hset_t &s) : _i (s.first ()), _set (s) {}
  const handle_t * next () ;
private:
  const hset_slot_t *_i;
  const hset_t &_set;
};

template<class V>
class hmap_t : public qhash<handle_t, V>
{
public:
  hmap_t () : qhash<handle_t, V> () {}
  bool start (handle_t *h, V *v) const;
  bool next (handle_t *h, V *v) const;
private:
  bool iterate (handle_t *h, V *v) const;
  mutable qhash_slot<handle_t, V> *_iterator;
};

class capmap_t : public hmap_t<int>
{
public:
  capmap_t () : hmap_t<int> () {}
  void addops (handle_t h, int i);
};

ptr<label_t> set_xor (const label_t &l1, const label_t &l2);
ptr<const label_t> set_xor (ptr<const label_t> l1, ptr<const label_t> l2);

class label_t {
public:
  label_t () : _is_infinite (false) {}
  label_t (const x_label_t &x);
  label_t (const x_label_t *x);
  label_t (const str &f);
  label_t (const label_t &l);
  virtual ~label_t () {}

  static ptr<label_t> alloc (const x_label_t &x)
  { return New refcounted<label_t> (x); }
  static ptr<label_t> alloc (const x_label_t *x)
  { return New refcounted<label_t> (x); }

  bool is_flatlabel () const;
  void set_infinite () { _is_infinite = true; }
  bool is_infinite  () const { return _is_infinite; }
  bool is_empty () const { return _map.size () == 0 && !_is_infinite; }

  ptr<label_t> clone () const { return New refcounted<label_t> (*this); }

  static str label2str (const label_t *in);

  static bool eq (const label_t *l1, const label_t *l2);
  bool eq (const label_t *l) const;
  bool operator== (const label_t &l) const { return eq (&l); }
  bool operator== (const label_t *l) const { return eq (l); }
  label_t &operator= (const label_t &in) { copy (in); return *this; }
  void copy (const label_t &in);

  bool operator[] (const handle_t &h) const { return contains (h); }
  bool contains (const handle_t &h) const; 
  virtual bool contains (const handle_t &h, handle_prefix_t prfx) const ;

  bool subset_of (const label_t *l1, const label_t *l2) const;
  bool subset_of (const label_t *l1) const;
  bool subset_of (const label_t **rhs2) const;

  bool from_str (str s);

  virtual void insert (const handle_t &h) { _map.insert (h); }
  virtual void remove (const handle_t &h) { _map.remove (h); }
  virtual void clear () { _map.clear (); }
  virtual void export_groups (vec<handle_t> *out) const {}

  void union_in (const x_label_t &x);
  bool superset_of (const x_label_t &x);

  void subtract (const label_t &l2, label_t *out) const;
  ptr<label_t> subtract (const label_t &l) const;

  ptr<label_t> set_xor (const label_t &l2) const
  { return ::set_xor (*this, l2); }

  void union_in_diff (const label_t &l1, const label_t &l2);

  static str freeze (x_label_t *x);
  str freeze () const;
  str to_str () const;
  virtual str to_str (setcmp_type_t typ) const;

  void from_xdr (const x_label_t &x);
  void to_xdr (x_label_t *x) const;
  void to_xdr (rpc_ptr<x_label_t> *x) const;
  
  hset_t &map () { return _map; }
  const hset_t &map () const { return _map; }

  bool is_valid () const;

  virtual bool is_appropriate (const handle_t &h) const
  { return !h.is_capability (); }
  bool is_persistent () const;

  hash_t hsh () const;

protected:
  hset_t _map;
  bool _is_infinite;
private:
  void init (const x_label_t &x);
};

class capset_t : public label_t {
public:
  capset_t (const label_t &l);
  capset_t (const capset_t &l);
  capset_t (const x_label_t &x);
  capset_t (const x_label_t *x);
  capset_t () : label_t () {}
  ~capset_t () {}
  void export_groups (vec<handle_t> *out) const;

  bool is_appropriate (const handle_t &h) const 
  { return h.is_capability (); }

  static ptr<capset_t> alloc (const x_label_t &x)
  { return New refcounted<capset_t> (x); }

  static ptr<label_t> virtual_alloc (const x_label_t &x);

  virtual bool contains (const handle_t &h, handle_prefix_t prfx) const 
  { return _map[capability_t (prfx, h)]; }
  bool contains (const handle_t &h) const { return _map[h]; }
  
  virtual str to_str (setcmp_type_t typ) const;

  void insert (const handle_t &h);
  void remove (const handle_t &h);
  void clear () { label_t::clear (); _groups.clear (); }
protected:
  hset_t _groups;
private:
  void init (const x_label_t &x);
};

class labelset_t {
public:
  labelset_t () {}
  labelset_t (const x_labelset_t &x)
    : _S_label (label_t::alloc (x.S)),
      _I_label (label_t::alloc (x.I)),
      _O_label (x.O ? capset_t::alloc (*x.O) : NULL) {}

  static ptr<labelset_t>
  alloc (const x_labelset_t &x) { return New refcounted<labelset_t> (x); }

  labelset_t (int which)
    : _S_label ( (which & LABEL_S) ? New refcounted<label_t> () : NULL),
      _I_label ( (which & LABEL_I) ? New refcounted<label_t> () : NULL),
      _O_label ( (which & LABEL_O) ? New refcounted<capset_t> () : NULL) {}

  void to_xdr (x_labelset_t *x) const
  {
    if (_S_label) _S_label->to_xdr (&x->S);
    if (_I_label) _I_label->to_xdr (&x->I);
    if (_O_label) {
      x->O.alloc ();
      _O_label->to_xdr (x->O);
    }
  }

  static ptr<labelset_t> null () { return New refcounted<labelset_t> (); }

  bool filled (int which) const
  {
    return ( ( !(which & LABEL_S) || S() ) &&
	     ( !(which & LABEL_I) || I() ) &&
	     ( !(which & LABEL_O) || O() ) );
  }

  // The minimum possible labe is an empty S label and an infinite
  // I label.
  bool is_minimum () const {
    return ((!S() || S()->is_empty()) && I() && I()->is_infinite ()); 
  }

  ptr<const label_t>  S () const { return _S_label; }
  ptr<const label_t>  I () const { return _I_label; }
  ptr<const capset_t> O () const { return _O_label; }

  ptr<label_t>  S () { return _S_label; }
  ptr<label_t>  I () { return _I_label; }
  ptr<capset_t> O () { return _O_label; }

  ptr<capset_t> O_notnull();

  ptr<label_t>  *S_pointer () { return &_S_label; }
  ptr<label_t>  *I_pointer () { return &_I_label; }
  ptr<capset_t> *O_pointer () { return &_O_label; }

  void set_S (ptr<label_t> s)  { _S_label = s; }
  void set_I (ptr<label_t> i)  { _I_label = i; }
  void set_O (ptr<capset_t> o) { _O_label = o; }

  void set_label (int which, ptr<label_t> l);

  void clear_S () { _S_label = NULL; }
  void clear_I () { _I_label = NULL; }

  str to_str (int which = LABEL_ALL) const;
  bool from_str (const str &in);

  void set_all (ptr<label_t> s, ptr<label_t> i, ptr<capset_t> o)
  { _S_label = s;  _I_label = i;  _O_label = o; }

  bool can_send_to (const labelset_t &l2) const
  { 
    return can_send_S (l2) && can_send_I (l2);
  }

  bool is_persistent () const
  {
    return ((!S() || S()->is_persistent()) &&
	    (!I() || I()->is_persistent()) &&
	    (!O() || O()->is_persistent()));
  }

  bool can_send_S (const labelset_t &l2) const
  {
    ptr<const label_t> s2 (l2.S ());
    return ((!_S_label || _S_label->subset_of (s2)));
  }

  bool can_send_I (const labelset_t &l2) const
  {
    ptr<const label_t> i2 (l2.I ());
    return (!i2 || i2->subset_of (_I_label)); 
  }
  
  bool operator<= (const labelset_t &l2) const { return can_send_to (l2); }

  ptr<labelset_t> clone (int which = LABEL_NO_O)
  {
    ptr<labelset_t> n = New refcounted<labelset_t> ();
    if (which & LABEL_S) n->set_S (S());
    if (which & LABEL_I) n->set_I (I());
    if (which & LABEL_O) n->set_O (O());
    return n;
  }

  void clone_I () { if (I()) set_I (I()->clone ()); }
  void clone_S () { if (S()) set_S (S()->clone ()); }

  ptr<labelset_t> deep_clone (int which = LABEL_NO_O) const
  {
    ptr<labelset_t> n = New refcounted<labelset_t> ();
    if (which & LABEL_S) 
      n->set_S (S() ? New refcounted<label_t> (*S()) : NULL);
    if (which & LABEL_I) 
      n->set_I (I() ? New refcounted<label_t> (*I()) : NULL);
    if (which & LABEL_O) 
      n->set_O (O() ? New refcounted<capset_t> (*O()) : NULL);
    return n;
  }

  ptr<labelset_t> clone (ptr<capset_t> O)
  {
    ptr<labelset_t> n = clone (LABEL_NO_O);
    n->set_O (O);
    return n;
  }

  bool eq (const labelset_t &in, int which = LABEL_NO_O) const;
  bool operator== (const labelset_t &in) const { return eq (in, LABEL_NO_O); }
  hash_t hsh (int which = LABEL_NO_O) const;

protected:  
  ptr<label_t>       _S_label;
  ptr<label_t>       _I_label;
  ptr<capset_t>      _O_label;
};

template<> struct equals<labelset_t> {
  equals () {}
  bool operator () (const labelset_t &l1, const labelset_t &l2) const
  { return l1 == l2; }
};

template<> struct hashfn<labelset_t> {
  hashfn () {}
  hash_t operator () (const labelset_t &l) const { return l.hsh(); }
};

template<class V> bool
hmap_t<V>::start (handle_t *h, V *v) const
{
  _iterator = qhash<handle_t, V>::first ();
  return iterate (h, v);
}

template<class V> bool
hmap_t<V>::iterate (handle_t *h, V *v) const
{
  if (!_iterator) return false;
  else {
    *h = _iterator->key;
    *v = _iterator->value;
    return true;
  }
}

template<class V> bool
hmap_t<V>::next (handle_t *h, V *v) const
{
  if (_iterator) _iterator = qhash<handle_t, V>::next (_iterator);
  return iterate (h, v);
}

void subset_of_debug (const label_t *lhs, const label_t **rhs, 
		      setcmp_type_t typ);
void intersects_debug (const label_t *l, const label_t *r, int i);
void subset_of_debug_res (int res);
void pivot_nulls (const label_t **b, const label_t **right);

#define PERM_ERROR(res,s,...) \
do { \
   (res)->set_status (FLUME_EPERM); \
   (res)->eperm->desc = lset_error (s, ##__VA_ARGS__); \
} while (0)

str lset_error (const char *fmt, 
		const labelset_t *l1 = NULL, 
		const labelset_t *l2 = NULL,
		const labelset_t *l3 = NULL,
		const labelset_t *l4 = NULL);

void tok2bin (const priv_tok_t &tok, priv_tok_bin_t *bin);

#endif /* _FLUME_EV_LABELS_H_ */
