
#include "rxx.h"
#include "parseopt.h"
#include "flume_cpp.h"

#include "flume_debug.h"
#include "flume_ev_debug.h"
#include "flume_ev_labels.h"
#include "sha1.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

static str
ws_strip (const str &in)
{
	//python里面好像有描述！！！
  rxx x ("^\\s*(.*?)\\s*$");
  return x.match (in) ? x[1] : in;
}


handle_factory_t *hfact;

u_int64_t handle_t::_def_setuid_base = 0x1;

//-----------------------------------------------------------------------
///使用HANDLE_OPT_PERSISTENT前缀调用handle_t的构造函数
handle_t
handle_t::def_setuid_h ()
{
  return handle_t (HANDLE_OPT_PERSISTENT, _def_setuid_base);
}

//-----------------------------------------------------------------------
///构造函数
handle_factory_secure_t::handle_factory_secure_t (const str &key) : _i (0)
{
	//strbuf类型找不到！！！
  strbuf b ("%s-%d-%d", key.cstr (), getpid (), int (time (NULL)));
  str seed = b;
  bf_setkey (&_ctx, seed.cstr (), seed.len ());
}

//-----------------------------------------------------------------------
///使用p前缀调用handle_factory_secure_t构造函数
handle_t
handle_factory_secure_t::_newh (handle_prefix_t p)
{
  return handle_t (p, bf60_encipher (&_ctx, _i++));
}

//-----------------------------------------------------------------------
///label_t的构造函数
label_t::label_t (const x_label_t &x) : _is_infinite (false) { init (x); }

//-----------------------------------------------------------------------

///根据armor_type_t泪ing转换为string
//armor_type_t的几个类型 还不清楚此函数具体作用！！！
str
handle_t::to_str (armor_type_t base) const
{
  str out;
  switch (base) {
  case ARMOR_32_NIL:
    if (_value == 0) return "";
    // fall through
  case ARMOR_32_0:
    if (_value == 0) return "0";
    // fall through
  case ARMOR_32:
    return armor32 (static_cast<const void *> (&_value), sizeof (_value));
    break;
  default:
    out = strbuf ("0x%" PRIx64, _value);
    break;
  }
  return out;
}

//-----------------------------------------------------------------------
///label_t的构造函数
label_t::label_t (const x_label_t *x): _is_infinite (false) 
{ if (x) init (*x); }

//-----------------------------------------------------------------------
///capset_t的构造函数
capset_t::capset_t (const x_label_t &x) : label_t (x) { init (x); }

//-----------------------------------------------------------------------
///capset_t的构造函数
capset_t::capset_t (const x_label_t *x) : label_t (x) { if (x) init (*x); }

//-----------------------------------------------------------------------


/*typedef unsigned hyper x_handle_t;
*typedef unsigned hyper x_caph_t;
*typedef x_handle_t x_label_t<>;
*typedef x_label_t x_handlevec_t;
*typedef unsigned handle_prefix_t;
*typedef string nickname_t<>;
*typedef string random_str_t<>;
*typedef string endpoint_desc_t<>;
*此处x_handle_t &x 不是一个unsigned hyper吗？
*/
///将x的值拷贝到_map
void
label_t::init (const x_label_t &x)
{
  for (size_t i = 0; i < x.size (); i++ ) {
    _map.insert (x[i]);
  }
}

//-----------------------------------------------------------------------
///label_t的构造函数
label_t::label_t (const label_t &in)
  : _is_infinite (in._is_infinite)
{
  copy (in);
}

//-----------------------------------------------------------------------
///capset_t的构造函数
capset_t::capset_t (const label_t &l)
{
  hset_iterator_t it (l.map ());
  const handle_t *h;
  while ((h = it.next ())) {
    //assert (h->is_capability ());
    insert (*h);
  }
}

//-----------------------------------------------------------------------
///capset_t的构造函数
capset_t::capset_t (const capset_t &l)
{
  hset_iterator_t it (l.map ());
  const handle_t *h;
  while ((h = it.next ())) {
    //assert (h->is_capability ());
    insert (*h);
  }
}

//-----------------------------------------------------------------------
///将x的值拷贝到_map，若x是group，再拷贝到_groups
void
capset_t::init (const x_label_t &x)
{
  for (size_t i = 0; i < x.size (); i++ ) {
    capability_t c (x[i]);
    //assert (c.is_capability ());
    insert (c);
  }
}

//-----------------------------------------------------------------------
///向_map和_groups插入h
void
capset_t::insert (const handle_t &h)
{
  //assert (h.is_capability ());
  label_t::insert (h);
  if (h.is_group ()) _groups.insert (h);
}

//-----------------------------------------------------------------------
///移除_groups中的h
void
capset_t::remove (const handle_t &h)
{
  label_t::remove (h);
  if (h.is_group ()) _groups.remove (h);
}

//-----------------------------------------------------------------------
///获取迭代器中的下一个对象
const handle_t *
hset_iterator_t::next ()
{
  const handle_t *h = NULL;
  if (_i) {
    h = &_i->key;
    _i = _set.next (_i);
  }
  return h;
}

//-----------------------------------------------------------------------
///判断调用在函数的label对象是否为标记标签
bool
label_t::is_flatlabel () const
{
  hset_iterator_t i (_map);
  const handle_t *k;
  while ((k = i.next ())) {
    if (!k->is_flat_handle ()) 
      return false;
  }
  return true;
}

//-----------------------------------------------------------------------
///handle_factory_t的初始化函数？？？（hfact是指向handle_factory_t的全局指针）
void
handle_factory_t::init (const str &seed)
{
  if (seed) {
    hfact = New handle_factory_secure_t (seed);
  } else {
    hfact = New handle_factory_debug_t ();
  }
}

//-----------------------------------------------------------------------
///判断两个标签是否相等
bool
label_t::eq (const label_t *l) const
{
  return l && subset_of (l) && l->subset_of (this);
}

//-----------------------------------------------------------------------
///向指定位置i出插入h
void
capmap_t::addops (handle_t h, int i)
{
  int *tmp = (*this)[h];
  if (tmp) *tmp |= i;
  else insert (h, i);
}

//-----------------------------------------------------------------------
///判断是否为x的超集
bool
label_t::superset_of (const x_label_t &x)
{
  for (size_t i = 0; i < x.size (); i++) {
    if (!contains (x[i])) return false;
  }
  return true;
}

//-----------------------------------------------------------------------
///并集
void
label_t::union_in (const x_label_t &x)
{
  for (size_t i = 0; i < x.size (); i++) {
    insert (x[i]);
  }
}

//-----------------------------------------------------------------------
///把label转换成外部label对象
void
label_t::to_xdr (x_label_t *x) const
{
  x->setsize (_map.size ());
  size_t i = 0;
  const handle_t *k;
  hset_iterator_t it (_map);
  while ((k = it.next ())) {
    (*x)[i] = *k;
    i++;
  }
}

//-----------------------------------------------------------------------
///根据外部label对象，初始化label对象
void
label_t::from_xdr (const x_label_t &x)
{
  clear ();
  init (x);
}

//-----------------------------------------------------------------------
///为快排写的函数指针函数
static int
hcmp (const void *v1, const void *v2)
{
  const x_handle_t *hp1 = static_cast<const x_handle_t *> (v1);
  const x_handle_t *hp2 = static_cast<const x_handle_t *> (v2);
  const x_handle_t &h1 = *hp1;
  const x_handle_t &h2 = *hp2;
  if (h1 < h2) return -1;
  else if (h1 == h2) return 0;
  else return 1;
}

//-----------------------------------------------------------------------
///把外部label中的handle快速排序之后再返回string类型

//qsort()中最后一个参数是一个 hcmp函数名  函数指针
str
label_t::freeze (x_label_t *x) 
{
  qsort (x->base (), x->size (), sizeof (x_handle_t), hcmp);
  strbuf b;
  bool first = true;
  for (size_t i = 0; i < x->size (); i++) {
    if (!first) b << ",";
    else first = false;
    handle_t h ((*x)[i]);
    //"0x%"此处格式？？？
    b.fmt ("0x%" PRIx64, h.value ());
  }
  return b;
}

//-----------------------------------------------------------------------
///把本对象label中的handle快速排序之后再返回string类型
str
label_t::freeze () const
{
  x_label_t x;
  to_xdr (&x);
  return freeze (&x);
}

//-----------------------------------------------------------------------
///是否包含handle h
bool
label_t::contains (const handle_t &h) const
{
  return _is_infinite || _map[h];
}

//-----------------------------------------------------------------------
///分配内存的函数
ptr<label_t>
capset_t::virtual_alloc (const x_label_t &x)
{
  bool is_capset = false;
  for (size_t i = 0; i < x.size () && !is_capset; i++) {
    if (handle_t (x[i]).is_capability ()) {
      is_capset = true;
    }
  }
  if (is_capset) {
    return capset_t::alloc (x);
  } else {
    return label_t::alloc (x);
  }
}

//-----------------------------------------------------------------------
///是否包含handle h
bool
label_t::contains (const handle_t &h, handle_prefix_t pfx) const
{
  return contains (h);
}


//-----------------------------------------------------------------------
///把标签转换为string
str
label_t::to_str () const
{
  strbuf b;
  bool first = true;
  hset_iterator_t i (_map);
  const handle_t *k;
  if (_is_infinite) {
    b << INFINITY_STR;
  } else {
    b << "[";
    while ((k = i.next ())) {
      if (!first) b << ",";
      else first = false;
      b << k->to_str ();
    }
    b << "]";
  }
  return b;
}

//-----------------------------------------------------------------------
///返回setcmp_type_t类型的字符串
const char *
set_repr (setcmp_type_t typ)
{
  switch (typ) {
  case COMPARE_ADD:       return "A_def";
  case COMPARE_SUBTRACT:  return "R_def";
  default:                return NULL;
  }
}

//-----------------------------------------------------------------------
///把标签转换为string
str
label_t::to_str (setcmp_type_t typ) const
{
  return to_str ();
}

//-----------------------------------------------------------------------
///把标签集转换成string
str
capset_t::to_str (setcmp_type_t typ) const
{
  str s = label_t::to_str ();
  strbuf b;
  switch (typ) {
  case COMPARE_ADD:
    b << "A(" << s << ")";
    break;
  case COMPARE_SUBTRACT:
    b << "R(" << s << ")";
    break;
  default:
    b << s;
    break;
  }
  return b;
}

//-----------------------------------------------------------------------
///label的构造函数
label_t::label_t (const str &s) : _is_infinite (false) { (void )from_str (s); }

//-----------------------------------------------------------------------
///根据输入的字符串，转换为label的_map
bool
label_t::from_str (str s)
{
  bool rc = true;
  s = ws_strip (s);
  if (s == INFINITY_STR) {
    _is_infinite = true;
  } else {
    rxx thaw_rxx ("\\s*,\\s*");
    rxx brace_rxx ("^\\[\\s*(.*?)\\s*\\]$");
    if (brace_rxx.match (s))
      s = brace_rxx[1];
      // vector可以简写vec? string可以简写str？ 还是别的用法
    vec<str> v;
    //vector<string> split(const string &s, const string &seperator); STL里split实现的方式 不一样！！！
    split (&v, thaw_rxx, s);
    for (size_t i = 0; i < v.size (); i++) {
      handle_t h;
      if (h.from_str (v[i])) {
	_map.insert (h);
      } else {
	rc = false;
      }
    }
  }
  return rc;
}

//-----------------------------------------------------------------------
///分配内存
handle_factory_t *
handle_factory_t::alloc (const str &s)
{
  if (s) { return New handle_factory_secure_t (s); }
  else { return New handle_factory_debug_t (); }
}

//-----------------------------------------------------------------------
///导出_groups
void
capset_t::export_groups (vec<handle_t> *out) const
{
  hset_iterator_t i (_groups);
  const handle_t *g;
  while ((g = i.next ())) {
    out->push_back (*g);
  }
}

//-----------------------------------------------------------------------
///是否为子集
bool
label_t::subset_of (const label_t *r1) const
{
  const label_t *v[2];
  v[0] = r1;
  v[1] = NULL;
  return subset_of (v);
}
 
//-----------------------------------------------------------------------
///是否为子集（两个label r1 r2）
bool
label_t::subset_of (const label_t *r1, const label_t *r2) const 
{
  const label_t *v[3];
  v[0] = r1;
  v[1] = r2;
  v[2] = NULL;

  pivot_nulls (v, v + 1);

  return subset_of (v);
}

//-----------------------------------------------------------------------
///标签是否包含此handle_t
bool
handle_t::contained_in (const label_t **rhs, handle_prefix_t cap) const
{
  const label_t **rhp;
  for (rhp = rhs; *rhp; rhp++) {
    if ((*rhp)->contains (*this, cap)) {
      return true;
    }
  }

  return false;
}

//-----------------------------------------------------------------------
///此标签是否包含rhs
bool
label_t::subset_of (const label_t **rhs) const
{
  hset_iterator_t i (_map);
  bool rc = true;
  setcmp_type_t typ = COMPARE_NONE;
  const handle_t *k;

  subset_of_debug (this, rhs, typ);

  while ((k = i.next ()) && rc) {
    if (!k->contained_in (rhs, 0)) {
      rc = false;
    }
  }

  subset_of_debug_res (rc);

  return rc;
}

//-----------------------------------------------------------------------
///判断handle是否由字符串s转换而来？
bool
handle_t::from_str (const str &s)
{
  bool ret = true;
  char *endptr;
  _value = strtoull (s.cstr(), &endptr, 0);
  if (*endptr || 
      (_value == ULLONG_MAX && errno == ERANGE) ||
      (_value == 0 && errno == EINVAL)) {

//dearmor32()函数？？？
    str x = dearmor32 (s);
    if (x && x.len () == sizeof (_value)) {
      memcpy (static_cast<void *> (&_value), x.cstr (), x.len ());
    } else {
      ret = false;
    }
  }
  return ret;
}

//-----------------------------------------------------------------------
///向_already_seen插入h
void
handle_factory_t::remote_alloc (handle_t h)
{
  _already_seen.insert (h);
}

//-----------------------------------------------------------------------
///新建一个handle_factory_t的对象？
handle_t
handle_factory_t::newh ()
{
  return newh (handle_prefix_t (0), true);
}

//-----------------------------------------------------------------------
///新建一个handle_factory_t的对象？
handle_t
handle_factory_t::newh (handle_prefix_t p, bool no_handle_val_dups)
{
  return no_handle_val_dups ? _newh_reliable (p) : _newh (p);
}

//-----------------------------------------------------------------------
///新建一个reliabled的handle_factory_t的对象？
handle_t
handle_factory_t::_newh_reliable (handle_prefix_t p)
{
  bool ok (false);
  handle_t ret;

  while (!ok) {
    ret = _newh (p);
    if (!_already_seen[ret]) {
      ok = true;
      _already_seen.insert (ret);
    }
  }
  return ret;
}

//-----------------------------------------------------------------------
///判断handle_it_t是否从string转换而来，并设置其前缀_prefix
bool
handle_id_t::from_str (const str &s)
{
  rxx x ("([^:]+:)?(.+)");
  if (!x.match (s)) 
    return false;
  _name = x[2];
  _prefix = 0;

  bool rc = true;
  if (x[1].cstr ()) {
    for (const char *cp = x[1].cstr (); *cp; cp++) {
      switch (*cp) {
      case 'a':
	_prefix |= HANDLE_OPT_DEFAULT_ADD;
	break;
      case 'g':
	// Implicitly add persistence, since there is no such thing as
	// a temporary group, for now.
	_prefix |= (HANDLE_OPT_GROUP | HANDLE_OPT_PERSISTENT);
	break;
      case 'p':
	_prefix |= HANDLE_OPT_PERSISTENT;
	break;
      case 'r':
	_prefix |= HANDLE_OPT_DEFAULT_SUBTRACT;
	break;
      case 'i':
	_prefix |= HANDLE_OPT_IDENTIFIER;
	break;
      case 'A':
	_prefix |= CAPABILITY_ADD;
	break;
      case 'R':
	_prefix |= CAPABILITY_SUBTRACT;
	break;
      case 'G':
	_prefix |= CAPABILITY_GROUP_SELECT;
	break;
      case ':':
	break;
      default:
	return false;
      }
    }
  }
  _is_cap = is_capability (prefix ()); 
  _hsh = mkhsh ();
  return rc;
}

//-----------------------------------------------------------------------
///前缀转换成string
str
prefix2str (handle_prefix_t p)
{
  strbuf b;
  if (p & HANDLE_OPT_PERSISTENT)       b << "p";
  if (p & HANDLE_OPT_GROUP)            b << "g";
  if (p & HANDLE_OPT_DEFAULT_ADD)      b << "a";
  if (p & HANDLE_OPT_DEFAULT_SUBTRACT) b << "r";
  if (p & HANDLE_OPT_IDENTIFIER)       b << "i";
  if (p & CAPABILITY_ADD)              b << "A";
  if (p & CAPABILITY_SUBTRACT)         b << "R";
  if (p & CAPABILITY_GROUP_SELECT)     b << "G";
  return b;
}

//-----------------------------------------------------------------------
///转换成string
str
handle_id_t::to_str () const
{
  strbuf b;
  b.fmt ("[%s:%s]", prefix2str (_prefix).cstr (), _name.cstr ());
  return b;
}

//-----------------------------------------------------------------------
///转换到外部数据
void
handle_id_t::to_xdr (new_handle_arg_t *x) const
{
  x->prefix = _prefix;
  x->name = _name;
}

//-----------------------------------------------------------------------
///对handle_id的名字和前缀做字节hash操作
//hash_t是什么数据类型？
hash_t 
handle_id_t::mkhsh () const 
{
  if (!_name) return 0;
  strbuf b;
  b << _name <<  _prefix ;
  str s = b;
  return hash_bytes (s.cstr (), s.len ());
}

//-----------------------------------------------------------------------
///。。。
//此函数？？？
bool 
is_valid (handle_prefix_t p) { return true; }

//-----------------------------------------------------------------------
///handle选项是否为持久的
bool
is_persistent (handle_prefix_t p) { return p & HANDLE_OPT_PERSISTENT; }

//-----------------------------------------------------------------------
///handle选项是否为组
bool
is_group (handle_prefix_t p) { return p & HANDLE_OPT_GROUP; }

//-----------------------------------------------------------------------
///handle选项是否为默认的加
bool 
is_default_add (handle_prefix_t p) 
{ return p & HANDLE_OPT_DEFAULT_ADD; }

//-----------------------------------------------------------------------
///handle选项是否为默认的减
bool 
is_default_subtract (handle_prefix_t p) 
{ return p & HANDLE_OPT_DEFAULT_SUBTRACT; }

//-----------------------------------------------------------------------
///是否为capability标记位
bool
is_capability (handle_prefix_t p) { return p & CAPABILITY_BITS; }

//-----------------------------------------------------------------------
///向handle添加capability标签
void
handle_t::add_capabilities (label_t *O)
{
  if (is_group ()) {
    O->insert (capability_t (CAPABILITY_GROUP_SELECT, *this));
  } else if (is_identifier ()) {
    O->insert (capability_t (CAPABILITY_GENERIC, *this)); 
  } else {
  	//if (!is_default_add ()) ？？？  is_default_add ()等函数调用时不添加参数吗？
    if (!is_default_add ()) 
      O->insert (capability_t (CAPABILITY_ADD, *this));
    if (!is_default_subtract ())
      O->insert (capability_t (CAPABILITY_SUBTRACT, *this));
  }
}

//-----------------------------------------------------------------------
///集合求异或
ptr<label_t>
set_xor (const label_t &l1, const label_t &l2)
{
  ptr<label_t> r = New refcounted<label_t> ();
  r->union_in_diff (l1, l2);
  r->union_in_diff (l2, l1);
  return r;
}

//-----------------------------------------------------------------------
///集合减法
ptr<label_t>
label_t::subtract (const label_t &l) const
{
  ptr<label_t> r = New refcounted<label_t> ();
  subtract (l, r);
  return r;
}

//-----------------------------------------------------------------------
///集合减法
void
label_t::subtract (const label_t &l2, label_t *out) const
{
  out->union_in_diff (*this, l2);
}

//-----------------------------------------------------------------------
///集合异或
ptr<const label_t>
set_xor (ptr<const label_t> l1, ptr<const label_t> l2)
{
  if (!l1) return l2;
  if (!l2) return l1;
  return set_xor (*l1, *l2);
}

//-----------------------------------------------------------------------
///集合联合相异元素
void
label_t::union_in_diff (const label_t &l1, const label_t &l2)
{
  hset_iterator_t it (l1.map ());
  const handle_t *h;
  while ((h = it.next ()))
    if (!l2[*h])
      insert (*h);
}

//-----------------------------------------------------------------------
///把labelset转换成string
str
labelset_t::to_str (int which) const
{
  strbuf b;
  str o, i, s;
  vec<str> v;

#define doit(v, in, lab) \
do { \
  str s = in; \
  strbuf b; \
  b << lab << " : " << s ; \
  v.push_back (b); \
}  while (0)
  
  if ((which & LABEL_S) && S()) { doit (v, S()->to_str (), "S"); }
  if ((which & LABEL_I) && I()) { doit (v, I()->to_str (), "I"); }
  if ((which & LABEL_O) && O()) { doit (v, O()->label_t::to_str (), "O"); }

#undef doit

  b << "{";
  for (size_t i = 0; i < v.size (); i++) {
    if (i > 0) b << " , " ;
    b << v[i];
  }
  b << "}";
  return b;
}


//-----------------------------------------------------------------------
///判断label是否为有效的
bool
label_t::is_valid () const
{
  hset_iterator_t it (map ());
  const handle_t *h;
  while ((h = it.next ())) {
    if (!is_appropriate (*h))
      return false;
  }
  return true;
}

//-----------------------------------------------------------------------
///判断label是否为持久的
bool
label_t::is_persistent () const
{
  hset_iterator_t it (map ());
  const handle_t *h;
  while ((h = it.next ())) {
    if (!h->is_persistent ())
      return false;
  }
  return true;
}

//-----------------------------------------------------------------------
///判断label是否为为标识符
bool
is_identifier (handle_prefix_t p) { return p & HANDLE_OPT_IDENTIFIER; }

//-----------------------------------------------------------------------
///判断label是否为为标识符
void
intersects_debug (const label_t *lhs, const label_t *rhs, int rc)
{
  if (FLUMEDBG2(LABELOPS)) {
    strbuf b;
    str e = "{}";
    str l = lhs ? lhs->to_str () : e;
    str r = rhs ? rhs->to_str () : e;
    b << "Intersects: " << l << " ^ " << r << "\n";
    b << "  -> Result = " << rc << "\n";
    flumedbg_warn (CHATTER, b);
  }

}

//-----------------------------------------------------------------------

void 
subset_of_debug (const label_t *lhs, const label_t **rhs, setcmp_type_t typ)
{
  const label_t **rhp;

  if (FLUMEDBG2(LABELOPS)) {
    strbuf b;
    str e = "[]";

    str l = lhs ? lhs->to_str () : e;
    b << "Subset comparison: ";
    b.cat (l.cstr (), true);
    b << " [= " ;

    bool first = true;
    for (rhp = rhs; *rhp; rhp++) {
      if (!first) b << " U ";
      else first = false;

      l = (*rhp)->to_str (typ);
      b.cat (l.cstr (), true);
    }
    if (set_repr (typ)) {
      if (!first) b << " U ";
      b << set_repr (typ);
    }
    b << "\n";
    flumedbg_warn (CHATTER, b);
  }
}

//-----------------------------------------------------------------------

void
subset_of_debug_res (int res)
{
  if (FLUMEDBG2(LABELOPS)) {
    flumedbg_warn (CHATTER, " Result: %d\n", res);
  }
}

//-----------------------------------------------------------------------

// pivot the given array so that all NULL pointers are on the right
// side and all non-NULL pointers are on the left side.
void
pivot_nulls (const label_t **b, const label_t **right)
{
  const label_t **left = b;
  const label_t *tmp;
  
  while (left < right) {
    if (*left) 
      left ++;
    else {
      tmp = *left;
      *left = *right;
      *right = tmp;
    }
    // subtract right past all 
    while (*right == NULL && right > b) right--;
  }
}

//-----------------------------------------------------------------------

ptr<capset_t>
labelset_t::O_notnull ()
{
  if (!_O_label) 
    _O_label = New refcounted<capset_t> ();

  return _O_label;
}

//-----------------------------------------------------------------------

void
label_t::copy (const label_t &in)
{
  hset_iterator_t it (in.map ());
  const handle_t *h;
  while ((h = it.next ())) {
    insert (*h);
  }
}

//-----------------------------------------------------------------------

bool
labelset_t::from_str (const str &in)
{
  rxx x1 ("^\\s*\\{\\s*(.*?)\\s*\\}\\s*$");
  if (!x1.match (in)) 
    return false;
  str s = x1[1];
  bool rc = true;
  
  while (s && s.len () && rc) {
    rxx x2 ("^([iIsSoO])\\s*:\\s*(\\[(.*?)\\]\\s*|[^[\\],]*)(.*)$");
    if (x2.match (s)) {
      str which = x2[1];
      str lab = x2[2];
      str rest = x2[4];
      ptr<label_t> l = New refcounted<label_t> ();
      if (l->from_str (lab)) {
	switch (which[0]) {
	case 'i': case 'I':
	  set_I (l);
	  break;
	case 's': case 'S':
	  set_S (l);
	  break;
	case 'o': case 'O':
	  set_O (New refcounted<capset_t> (*l));
	  break;
	default:
	  panic ("RXX weirdness\n");
	}
	rxx x3 ("^\\s*(,)?\\s*(.*)$");
	if (!x3.match (rest)) {
	  rc = false;
	} else {
	  s = x3[2];
	}
      } else {
	rc = false;
      }
    }
  }
  return rc;
}

//-----------------------------------------------------------------------

str
status2str (flume_status_t st)
{
  strbuf b;
  rpc_print (b, st);
  return b;
}

//-----------------------------------------------------------------------

str
lset_error (const char *fmt, const labelset_t *l1, const labelset_t *l2,
	    const labelset_t *l3, const labelset_t *l4)
{
  str s1, s2, s3, s4;
  int opt = LABEL_NO_O;
  strbuf b;
  if (l1) {
    s1 = l1->to_str (opt);
    if (l2) {
      s2 = l2->to_str (opt);
      if (l3) {
	s3 = l3->to_str (opt);
	if (l4) {
	  s4 = l4->to_str (opt);
	  b.fmt (fmt, s1.cstr (), s2.cstr (), s3.cstr (), s4.cstr ());
	} else {
	  b.fmt (fmt, s1.cstr (), s2.cstr (), s3.cstr ());
	}
      } else {
	b.fmt (fmt, s1.cstr (), s2.cstr ());
      }
    } else {
      b.fmt (fmt, s1.cstr ());
    }
  } else {
    b.fmt (fmt);
  }
  return b;
}

//-----------------------------------------------------------------------

void
tok2bin (const priv_tok_t &tok, priv_tok_bin_t *bin)
{
  if (tok.typ == PRIV_TOK_BINARY) {
    memcpy (bin->base (), tok.bintok->base (), BINTOKSZ);
  } else if (tok.typ == PRIV_TOK_STR) {
    str s = *tok.strtok;
    sha1_hash (bin, s.cstr (), s.len ());
  }
}

//-----------------------------------------------------------------------

str
label_t::label2str (const label_t *in)
{
  if (!in) return "[]"; 
  else     return in->to_str ();
}

//-----------------------------------------------------------------------

const char *
labeltyp2str (label_type_t t)
{
  switch (t) {
  case LABEL_S: return "S";
  case LABEL_O: return "O";
  case LABEL_I: return "I";
  default: break;
  }
  return "<unknown>";

}

//-----------------------------------------------------------------------

hash_t
label_t::hsh () const
{
  hash_t ret = 0;
  if (_is_infinite) {
    ret = 0x1;
  } else {
    hset_iterator_t it (_map);
    const handle_t *h;
    while ((h = it.next ())) {
      ret = (ret ^ h->hsh ());
    }
  }
  return ret;
}

//-----------------------------------------------------------------------

hash_t
labelset_t::hsh (int which) const 
{
  hash_t ret = 
    (_S_label && (which & LABEL_S) ? _S_label->hsh () : hash_t (0)) ^
    (_I_label && (which & LABEL_I) ? _I_label->hsh () * 3 : 0) ^
    (_O_label && (which & LABEL_O) ? _O_label->hsh () * 7 : 0);

  return ret;
}

//-----------------------------------------------------------------------

bool
labelset_t::eq (const labelset_t &in, int which) const
{
  return ((!(which && LABEL_S) || label_t::eq (in.S(), _S_label)) && 
	  (!(which && LABEL_I) || label_t::eq (in.I(), _I_label)) &&
	  (!(which && LABEL_O) || label_t::eq (in.O(), _O_label)));
}

//-----------------------------------------------------------------------

bool
label_t::eq (const label_t *l1, const label_t *l2)
{
  return ((!l1 || l1->is_empty ()) && (!l2 || l2->is_empty ()) ||
	  (l1 && l2 && *l1 == *l2));
}

//-----------------------------------------------------------------------

void 
labelset_t::set_label (int which, ptr<label_t> l)
{
  switch (which) {
  case LABEL_I: _I_label = l; break;
  case LABEL_S: _S_label = l; break;
  default: panic ("bad label type\n");
  }
}

//-----------------------------------------------------------------------

void
label_t::to_xdr (rpc_ptr<x_label_t> *x) const
{
  x->alloc ();
  to_xdr (*x);
}


//-----------------------------------------------------------------------
