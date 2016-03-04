
#include "flume_features.h"

#include <stdlib.h>
#include <limits.h>
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/time.h>
#include "flume_prot.h"
#include <errno.h>
#include <assert.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <unistd.h>

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_clnt.h"
#include "flume_internal.h"

/*
 * -----------------------------------------------------------------------
 * X_copy_v
 */

static void
label_copy_v (x_label_t *out, const x_label_t *in)
{ 
  assert (in->len == out->len); 
  memcpy ((void *)out->val, in->val, sizeof (x_handle_t) * in->len);
}

static void
int_set_copy_v (x_int_set_t *out, const x_int_set_t *in)
{
  assert (in->len == out->len);
  memcpy ((void *)out->val, in->val, sizeof (int) * in->len);
}

static void
endpoint_set_copy_v (x_endpoint_set_t *out, const x_endpoint_set_t *in)
{
  u_int i;
  assert (in->len == out->len); 
  for (i = 0; i < out->len; i++) {
    endpoint_copy (&out->val[i], &in->val[i]);
  }
}

static void
label_change_set_copy_v (x_label_change_set_t *out, 
			 const x_label_change_set_t *in)
{
  u_int i;
  assert (in->len == out->len);
  for (i = 0; i < out->len; i++) {
    label_change_copy (&out->val[i], &in->val[i]);
  }
}

static void
capability_op_set_copy_v (x_capability_op_set_t *out,
			  const x_capability_op_set_t *in)
{
  assert (in->len == out->len);
  memcpy ((void *)out->val, in->val, sizeof (x_capability_op_t) * out->len);
}

/*
 * -----------------------------------------------------------------------
 * X_clear_slice
 *
 */

static void 
endpoint_set_clear_slice (x_endpoint_t *v, u_int s, u_int e)
{
  u_int i;
  for (i = s; i < e; i++) {
    endpoint_clear (v + i);
  }
}


static void
label_change_set_clear_slice (x_label_change_t *v, u_int s, u_int e)
{
  u_int i;
  for (i = s; i < e; i++) {
    label_change_clear (v + i);
  }
}

static void int_set_clear_slice (int *v, u_int s, u_int e) {}
static void label_clear_slice (x_handle_t *v, u_int s, u_int e) {}
static void capability_op_set_clear_slice (x_capability_op_t *x, u_int s, 
					   u_int e) {}

/*
 * -----------------------------------------------------------------------
 * X_clear_v
 *
 */

static void
label_clear_v (x_label_t *x)
{
  if (x->val) {
    free (x->val);
    x->val = NULL;
  }
}

static void
capability_op_set_clear_v (x_capability_op_set_t *x)
{
  if (x->val) {
    free (x->val);
    x->val = NULL;
  }
}


// must be called before x->len is reset!
static void
endpoint_set_clear_v (x_endpoint_set_t *x)
{
  if (x->val) {
    endpoint_set_clear_slice (x->val, 0, x->len);
    free (x->val);
    x->val = NULL;
  }
}

static void
label_change_set_clear_v (x_label_change_set_t *x)
{
  if (x->val) {
    label_change_set_clear_slice (x->val, 0, x->len);
    free (x->val);
    x->val = NULL;
  }
}

static void
int_set_clear_v (x_int_set_t *x)
{
  if (x->val) {
    free (x->val);
    x->val = NULL;
  }
}

/*
 * -----------------------------------------------------------------------
 */


#define ARRAY_ALLOC(typ, prfx, elem)                          \
typ *                                                         \
prfx##_alloc (u_int sz)                                       \
{                                                             \
  size_t asz = sz * sizeof (elem);                            \
  typ *ret = (typ *)malloc (sizeof (typ));                    \
  if (ret) {                                                  \
    ret->len = sz;                                            \
    if (sz > 0) {                                             \
      if (!(ret->val = (elem *)malloc (asz))) {               \
	FLUME_SET_ERRNO (FLUME_EMEM);                           \
	free (ret);                                           \
	ret = NULL;                                           \
      } else {                                                \
	memset ((void *)ret->val, 0, asz);                    \
      }                                                       \
    } else {                                                  \
      ret->val = NULL;                                        \
    }                                                         \
  } else {                                                    \
    FLUME_SET_ERRNO (FLUME_EMEM);                               \
  }                                                           \
  return ret;                                                 \
}

#define ARRAY_RESIZE(typ, prfx, elem)                         \
int                                                           \
prfx##_resize (typ *l, u_int sz, int cp)                      \
{                                                             \
  size_t oldsz, newsz;                                        \
  elem *v;                                                    \
  if (!l) {                                                   \
    FLUME_SET_ERRNO (FLUME_ENULL);                              \
    return -1;                                                \
  }                                                           \
  if (sz == 0) {                                              \
    prfx##_clear (l);                                         \
  } else if (l->len < sz) {                                   \
    newsz = sz * sizeof (elem);                               \
    if (!(v = (elem *)malloc (newsz))) {                      \
      FLUME_SET_ERRNO (FLUME_EMEM);                             \
      return -1;                                              \
    }                                                         \
    memset ((void *)v, 0, newsz);                             \
    if (l->val) {                                             \
      oldsz = l->len * sizeof (elem);                         \
      assert (oldsz < newsz);                                 \
      if (cp) {                                               \
	memcpy ((void *)v, l->val, oldsz);                    \
      } else {                                                \
        prfx##_clear_slice (l->val, 0, l->len);               \
      }                                                       \
      free (l->val);                                          \
    }                                                         \
    l->val = v;                                               \
  } else {                                                    \
    prfx##_clear_slice (l->val, sz, l->len);                  \
  }                                                           \
  l->len = sz;                                                \
  return 0;                                                   \
}

#define ARRAY_FREE(typ, prfx, elem) \
void \
prfx##_free(typ *l) \
{ \
  FLUME_DEBUG (FLUME_DEBUG_MEMORY, stderr, \
	      #prfx "_free (%p) called\n", l);\
  if (l) { \
    prfx##_clear_v (l); \
    free (l); \
  } \
}

#define ARRAY_SIZE(typ, prfx, elem) \
u_int prfx##_size (const typ *l) { return l->len; }

#define ARRAY_INIT(typ,prfx,elem) \
void \
prfx##_init (typ *l) \
{ \
  if (l) { \
    l->val = NULL; \
    l->len = 0; \
  } \
}

#define ARRAY_GETP(typ,prfx,elem) \
elem * \
prfx##_getp (typ *l, u_int off) \
{ \
  if (!l || off >= l->len) { \
    FLUME_SET_ERRNO (FLUME_ERANGE); \
    return NULL; \
  } \
  else return &l->val[off]; \
}

#define ARRAY_CLEAR(typ,prfx,elem) \
void \
prfx##_clear (typ *l) \
{ \
  if (!l) return; \
  if (l->val) { \
    prfx##_clear_slice (l->val, 0, l->len); \
    free (l->val); \
  } \
  l->val = NULL; \
  l->len = 0; \
}

#define ARRAY_CLONE(typ,prfx,elem) \
typ * \
prfx##_clone (const typ *in) \
{ \
  if (!in) { \
    FLUME_SET_ERRNO (FLUME_ENULL); \
    return NULL; \
  } \
\
  typ *out = prfx##_alloc (in->len); \
  if (out) { \
    prfx##_copy_v (out, in); \
  } \
  return out; \
}

#define ARRAY_COPY(typ,prfx,elem) \
int \
prfx##_copy (typ *out, const typ *in) \
{ \
  int rc = 0; \
  if (!out) { \
    FLUME_SET_ERRNO (FLUME_ENULL); \
    rc = -1; \
  } else if (!in) { \
    prfx##_clear (out); \
    rc = 0; \
  } else if (prfx##_resize (out, in->len, 0) == 0) { \
    prfx##_copy_v (out, in); \
  } else { \
    rc = -1; \
  } \
  return rc; \
}

#define FROM_RAW(typ,prfx)					\
  int prfx##_from_raw (typ *out, const void *in, size_t sz)	\
  {								\
    typ obj;							\
    memset (&obj, 0, sizeof (obj));				\
    int rc = c_str2xdr (&obj, (xdrproc_t )xdr_##typ, in, sz);	\
    if (rc >= 0) {						\
      rc = prfx##_copy (out, &obj);				\
    }								\
    xdr_free ((xdrproc_t )xdr_##typ, (char *)&obj);		\
    return rc;							\
  }

#define TO_RAW_STATIC(typ, prfx)					\
  ssize_t prfx##_to_raw_static (void *out, size_t sz, const typ *in)	\
  {									\
    ssize_t ret = -1;							\
    if (!in) {								\
      FLUME_SET_ERRNO (FLUME_ENULL);					\
    } else {								\
      ret = c_xdr2str (out, sz, (xdrproc_t )xdr_##typ, in);		\
    }									\
    return ret;								\
  }

#define TO_RAW(typ,prfx) \
  char *prfx##_to_raw (const typ *in, size_t *szp)		       \
  {								       \
    char buf[XDR_MAXSZ];					       \
    char *ret = NULL;						       \
    ssize_t sz = prfx##_to_raw_static (buf, XDR_MAXSZ, in);	       \
    if (sz > 0) {						       \
      ret = malloc (sz);					       \
      if (ret) {						       \
	memcpy (ret, buf, sz);					       \
	*szp = sz;						       \
      }								       \
    }								       \
    return ret;							       \
  }

#define RAWS(typ, prfx)				\
  FROM_RAW(typ,prfx)			        \
  TO_RAW_STATIC(typ,prfx)			\
  TO_RAW(typ,prfx)



#define ARRAY_DO_ALL(typ, prfx, elem) \
ARRAY_ALLOC(typ, prfx, elem) \
ARRAY_RESIZE(typ, prfx, elem) \
ARRAY_FREE(typ, prfx, elem) \
ARRAY_SIZE(typ, prfx, elem) \
ARRAY_INIT(typ, prfx, elem) \
ARRAY_GETP(typ, prfx, elem) \
ARRAY_CLEAR(typ, prfx, elem) \
ARRAY_CLONE(typ, prfx, elem) \
ARRAY_COPY(typ, prfx, elem) \
RAWS(typ, prfx)

/*
 * now actually define functions for the arrays we're using in our 
 * interface.  we can add arbitrarily many of these...
 */
ARRAY_DO_ALL(x_label_t, label, x_handle_t);
ARRAY_DO_ALL(x_endpoint_set_t, endpoint_set, x_endpoint_t);
ARRAY_DO_ALL(x_label_change_set_t, label_change_set, x_label_change_t);
ARRAY_DO_ALL(x_capability_op_set_t, capability_op_set, x_capability_op_t);
ARRAY_DO_ALL(x_int_set_t, int_set, int);

RAWS(x_labelset_t, labelset);
RAWS(x_handle_t, handle);
