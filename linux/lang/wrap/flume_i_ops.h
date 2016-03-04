

// -*-C++-*-

/*
 * Setup:
 *   There is some C object of type foo.
 *   There is some C object that is a set of things of type foo (foo_set).
 *
 * Idea:
 *  We want a C++ wrapper object to wrap foo_set in a clean way, so that
 *  we don't duplicate code in Python/swig. Thus, we'll collect all
 *  C functions that work on foo and foo_sets in a nice templated class,
 *  populate with function pointers to those functions.  Then a C++ wrapper
 *  around a foo_set can use this object to operate on the foo_set in 
 *  a generic manner.
 *
 */

template<class T>
class raw_ops_t {
public:
  typedef ssize_t (*to_static_t) (void *out, size_t lim, const T *in);
  typedef char * (*to_t) (const T *in, size_t *szp);
  typedef int (*from_t) (T *out, const void *in, size_t sz);
};

template<class T, class E>
class set_obj_ops_t {
public:
  typedef T * (*alloc_fn_t) (u_int sz);
  typedef int (*resize_fn_t) (T *o, u_int sz, int op);
  typedef void (*free_fn_t) (T *o);
  typedef u_int (*size_fn_t) (const T *o);
  typedef void (*init_fn_t) (T *o);
  typedef E * (*getp_fn_t) (T *p, u_int off);
  typedef void (*clear_fn_t) (T *o);
  typedef T * (*clone_fn_t) (const T *o);
  typedef int (*copy_fn_t) (T *out, const T *in);
  typedef int (*obj_copy_fn_t) (E *out, const E *in);
  typedef void (*obj_clear_fn_t) (E *in);

  typedef typename raw_ops_t<T>::to_static_t to_raw_fn_t;
  typedef typename raw_ops_t<T>::from_t from_raw_fn_t;

  set_obj_ops_t (const char *prfx,
		 alloc_fn_t allocfn,
		 resize_fn_t resizefn,
		 free_fn_t freefn,
		 size_fn_t sizefn,
		 init_fn_t initfn,
		 getp_fn_t getpfn,
		 clear_fn_t clearfn,
		 clone_fn_t clonefn,
		 copy_fn_t copyfn,
		 obj_clear_fn_t obj_clearfn,
		 obj_copy_fn_t obj_copyfn,
		 from_raw_fn_t fromrawfn,
		 to_raw_fn_t torawfn)
    : prfx (prfx),
      allocfn (allocfn),
      resizefn (resizefn),
      freefn (freefn),
      sizefn (sizefn),
      initfn (initfn),
      getpfn (getpfn),
      clearfn (clearfn),
      clonefn (clonefn),
      copyfn (copyfn),
      obj_clearfn (obj_clearfn),
      obj_copyfn (obj_copyfn),
      fromrawfn (fromrawfn),
      torawfn (torawfn) {}
	       
	       

  const char *prfx;
  alloc_fn_t allocfn;
  resize_fn_t resizefn;
  free_fn_t freefn;
  size_fn_t sizefn;
  init_fn_t initfn;
  getp_fn_t getpfn;
  clear_fn_t clearfn;
  clone_fn_t clonefn;
  copy_fn_t copyfn;
  obj_clear_fn_t obj_clearfn;
  obj_copy_fn_t obj_copyfn;
  from_raw_fn_t fromrawfn;
  to_raw_fn_t torawfn;
};

template<class T, class E> set_obj_ops_t<T,E> alloc_set_obj_ops ();

#define ALLOC_SET_OBJ_OPS(typ, prfx, elem, eprfx)		\
  template<> set_obj_ops_t<typ,elem>				\
  alloc_set_obj_ops ()						\
  {								\
    return set_obj_ops_t<typ,elem> (#prfx,			\
				    prfx##_alloc,		\
				    prfx##_resize,		\
				    prfx##_free,		\
				    prfx##_size,		\
				    prfx##_init,		\
				    prfx##_getp,		\
				    prfx##_clear,		\
				    prfx##_clone,		\
				    prfx##_copy,		\
				    eprfx##_clear,		\
				    eprfx##_copy,		\
				    prfx##_from_raw,		\
				    prfx##_to_raw_static);	\
  }
