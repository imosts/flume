
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
#include <inttypes.h>

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

//找到x_handle_t的定义！！！
x_handle_t
handle_construct (handle_prefix_t prfx, x_handle_t base)
{
  x_handle_t p = prfx;
  x_handle_t ret = handle_base (base) | ( p << HANDLE_SHIFT_BITS);
  return ret;
}

handle_prefix_t
handle_prefix (x_handle_t h)
{
  return (h >> HANDLE_SHIFT_BITS);
}

x_handle_t
handle_base (x_handle_t h)
{
  return (h & HANDLE_MASK);
}

int
handle_from_str (const char *s, x_handle_t *h)
{
  char *endptr;
  *h = strtoull (s, &endptr, 0);
  if (*endptr || 
      (*h == ULLONG_MAX && errno == ERANGE) ||
      (*h == 0 && errno == EINVAL)) {
    return -1;
  }
  return 0;
}

int
handle_from_armor (const char *s, x_handle_t *hp)
{
  char *out;
  size_t len;
  x_handle_t h;

  if (!s) {
    FLUME_SET_ERRNO (FLUME_ENULL);
    return -1;
  }

  out = dearmor32_c (s, strlen (s), &len);
  if (out && len == sizeof (h)) {
    memcpy ((void *)&h, out, len);
    *hp = h;
    return 0;
  }
  FLUME_SET_ERRNO (FLUME_EHANDLE);
  return -1;
}

x_handle_t
capability_construct (int prfx, x_handle_t h)
{
  return handle_construct (prfx | handle_prefix (h), handle_base (h));
}

x_handle_t 
label_get (const x_label_t *l, u_int off)
{ 
  if (!l || off >= l->len) {
    FLUME_SET_ERRNO (FLUME_ERANGE); 
    return 0ULL;
  } 
  else return l->val[off];
}

int 
label_set (x_label_t *l, u_int off, x_handle_t h) \
{ 
  if (!l || off >= l->len) {
    FLUME_SET_ERRNO (FLUME_ERANGE);
    return -1;
  }
  l->val[off] = h;
  return 0;
}

/* returns 1 if <lab> contains <h> */
int
label_contains (const x_label_t *lab, x_handle_t h)
{
  unsigned i;
  for (i=0; i<lab->len; i++)
    if (lab->val[i] == h)
      return 1;
  return 0;
}

/* return 1 if <x> is subset of <y>, return 0 otherwise */
int
label_is_subset (const x_label_t *x, const x_label_t *y)
{
  unsigned i;
  for (i=0; i<x->len; i++)
    if (!label_contains (y, x->val[i]))
      return 0;
  return 1;
}

void
label_print2 (FILE *s, const char *prefix, x_label_t *lab)
{
  unsigned i;
  fprintf (s, "%s {", prefix);
  for (i=0; i<lab->len; i++)
    fprintf (s, "%" PRIx64 "%s", lab->val[i], 
             i<lab->len-1 ? ", " : "");
  fprintf (s, "}");
}

void
label_print (FILE *s, x_label_t *lab)
{
  label_print2 (s, "", lab);
}

int
labelset_copy (x_labelset_t *out, const x_labelset_t *in) 
{
  int rc = 0;
  rc = labelset_set_S (out, labelset_get_S ((x_labelset_t *)in));
  if (rc == 0) rc = labelset_set_I (out, labelset_get_I ((x_labelset_t *)in));
  //O集合部分 Oi和Os?
  if (rc == 0) rc = labelset_set_O (out, labelset_get_O ((x_labelset_t *)in));
  return rc;
}

//filter 是啥？？？
int
filter_copy (x_filter_t *in, const x_filter_t *out)
{
  int rc;
  rc = label_copy (&in->find, &out->find);
  if (rc == 0) rc = label_copy (&in->replace, &out->replace);
  return rc;
}

x_labelset_t *
labelset_alloc (void)
{
  x_labelset_t *r = (x_labelset_t *)malloc (sizeof (x_labelset_t));
  if (r)
    memset ((void *)r, 0, sizeof (*r));
  return r;
}

//label_copy()定义在哪？
int
labelset_set_S (x_labelset_t *ls, const x_label_t *s)
{
  return label_copy (&ls->S, s);
}

int
labelset_set_I (x_labelset_t *ls, const x_label_t *i)
{
  return label_copy (&ls->I, i);
}

int
labelset_set_O (x_labelset_t *ls, const x_label_t *o)
{
  if (ls->O && o) {
    return label_copy (ls->O, o);
  } else if (o) {
    ls->O = label_clone (o);
    return ls->O ? 0 : -1;
  } else if (ls->O) {
	  //此处？？？
    label_clear (ls->O);
    return 0;
  } else {
    return 0;
  }
}

x_label_t *
labelset_get_I (x_labelset_t *ls)
{
  return &ls->I;
}

x_label_t *
labelset_get_S (x_labelset_t *ls)
{
  return &ls->S;
}

x_label_t *
labelset_get_O (x_labelset_t *ls)
{
  return ls->O;
}

int
labelset_alloc_O (x_labelset_t *ls, u_int sz)
{
  int rc;
  if (ls->O) {
    rc = label_resize (ls->O, sz, 1);
  } else {
    if ((ls->O = label_alloc (sz))) {
      rc = 0;
    } else {
      rc = -1;
    }
  }
  return rc;
}

void
labelset_clear (x_labelset_t *ls)
{
  label_clear (&ls->S);
  label_clear (&ls->I);
  if (ls->O) {
    label_free (ls->O);
    ls->O = NULL;
  }
}

void
labelset_free (x_labelset_t *ls)
{
  labelset_clear (ls);
  free (ls);
}

void
labelset_print (FILE *s, const char *prefix, x_labelset_t *ls)
{
  char buf[1024];

  snprintf (buf, 1024, "%s S label", prefix);
  label_print2 (s, buf, &ls->S);
  fprintf (s, "\n");

  snprintf (buf, 1024, "%s I label", prefix);
  label_print2 (s, buf, &ls->I);
  fprintf (s, "\n");

  snprintf (buf, 1024, "%s O label", prefix);
  if (ls->O) {
    label_print2 (s, buf, ls->O);
  } else {
    x_label_t *lab = label_alloc (0);
    label_print2 (s, buf, lab);
    label_free (lab);
  }
  fprintf (s, "\n");
}

x_filter_t *
filter_alloc ()
{
  x_filter_t *f = (x_filter_t *)malloc (sizeof (x_filter_t));
  if (f) {
    label_init (&f->find);
    label_init (&f->replace);
  }
  return f;
}

void 
filter_free (x_filter_t *f)
{
  free (f);
}

/* ----------------------------------------------------------------------- 
 * Endpoints!
 * ----------------------------------------------------------------------- 
 */

x_endpoint_t *
endpoint_alloc ()
{
  x_endpoint_t *r = (x_endpoint_t *)malloc (sizeof (x_endpoint_t));
  if (r)
    memset ((void *)r, 0, sizeof (*r));
  r->desc = strdup ("");
  return r;
}

void
endpoint_clear (x_endpoint_t *x)
{
#define Clear(field) \
  if (x->field) { \
    label_clear (x->field); \
    x->field = NULL; \
  }

  Clear(I);
  Clear(S);

  if (x->desc) {
    free (x->desc);
    x->desc = NULL;
  }

#undef C
}

void
endpoint_free (x_endpoint_t *x)
{
  endpoint_clear (x);
  free (x);
}

static int
endpoint_set_label (x_label_t **outp, const x_label_t *l)
{
  int rc = 0;
  x_label_t *out = *outp;

  if (!l) {
    if (out) { 
      label_clear (out);
      out = NULL;
    }
  } else {
    if (out == NULL) {
      if (!(out = label_alloc (label_size (l)))) {
	rc = -1;
      }
    }
    if (rc == 0) {
      rc = label_copy (out, l);
    }
  }
  *outp = out;

  return rc;
}

int
endpoint_set_I (x_endpoint_t *out, const x_label_t *l)
{
  return endpoint_set_label (&out->I, l);
}

int
endpoint_set_S (x_endpoint_t *out, const x_label_t *l)
{
  return endpoint_set_label (&out->S, l);
}

const char *
endpoint_get_desc (x_endpoint_t *x)
{
  return x->desc;
}

int
endpoint_copy (x_endpoint_t *out, const x_endpoint_t *in)
{
  int rc = 0;
  if (!in || !out) {
    FLUME_SET_ERRNO(FLUME_ENULL);
    return -1;
  }

  out->attributes = in->attributes;

  if (out->desc)
    free (out->desc);

  if (in->desc) {
    out->desc = strdup (in->desc);
  } else {
    out->desc = NULL;
  }

  if (in->S) { rc = endpoint_set_S (out, in->S); }
  if (rc == 0 && in->I) { rc = endpoint_set_I (out, in->I); }

  return rc;
}

x_label_t *endpoint_get_I (x_endpoint_t *ep) { return ep->I; }
x_label_t *endpoint_get_S (x_endpoint_t *ep) { return ep->S; }
u_int endpoint_get_attributes (x_endpoint_t *ep) { return ep->attributes; }

void 
endpoint_set_attributes (x_endpoint_t *ep, u_int a) 
{ ep->attributes = a; }


/* ----------------------------------------------------------------------- 
 * LabelChange objects!
 * ----------------------------------------------------------------------- 
 */

x_label_change_t *
label_change_alloc ()
{
  x_label_change_t *r = (x_label_change_t *)malloc (sizeof (x_label_change_t));
  if (r) {
    memset ((void *)r, 0, sizeof (*r));
    label_init (&r->label);
  } else {
    FLUME_SET_ERRNO (FLUME_EMEM);
  }
  return r;
}

void
label_change_clear (x_label_change_t *x)
{
  x->which = LABEL_NONE;
  label_clear (&x->label);
}

void
label_change_free (x_label_change_t *x)
{
  label_change_clear (x);
  free (x);
}

int 
label_change_set_label (x_label_change_t *x, const x_label_t *l)
{
  return label_copy (&x->label, l);
}

int
label_change_copy (x_label_change_t *out, const x_label_change_t *in)
{
  out->which = in->which;
  return label_copy (&out->label, &in->label);
}

x_label_change_t *
label_change_clone (const x_label_change_t *in)
{
  x_label_change_t *x = label_change_alloc ();
  if (x) {
    if (label_change_copy (x, in) < 0) {
      label_change_free (x);
      x = NULL;
    }
  }
  return x;
}

x_label_t *
label_change_get_label (x_label_change_t *x)
{
  return &x->label;
}

int
label_change_get_which (const x_label_change_t *x)
{
  return x->which;
}

int
label_change_set_which (x_label_change_t *x, int i)
{
  int rc = 0;
  if (i != LABEL_S && i != LABEL_I && i != LABEL_O) {
    rc = -FLUME_EINVAL;
  } else {
    x->which = i;
  }
  return rc;
}

void
capability_op_clear (x_capability_op_t *x)
{
  x->handle = 0;
  x->level = 0;
}

int
capability_op_copy (x_capability_op_t *out, const x_capability_op_t *in)
{
  if (in)
    *out = *in;
  else
    capability_op_clear (out);
  return 0;
}

void handle_clear (x_handle_t *h) { *h = 0ULL; }

int handle_copy (x_handle_t *out, const x_handle_t *in) 
{
  if (in)
    *out = *in;
  else
    handle_clear (out);
  return 0;
}

void int_clear (int *i) { *i = 0; }

int int_copy (int *out, const int *in) 
{
  if (in) *out = *in;
  else int_clear (out);
  return 0;
}

ssize_t
c_xdr2str (char *out, size_t outsz, 
	   xdrproc_t proc, const void *in)
{
  u_int32_t *buf = (u_int32_t *)out;
  XDR x;
  u_int32_t msgsize;
  size_t room;
  ssize_t rc;

  if (outsz < sizeof (msgsize)) {
    FLUME_SET_ERRNO (FLUME_ETOOSMALL);
    rc = -1;
  } else {
    room = outsz - sizeof (msgsize);
  
    xdrmem_create (&x, (char *)&buf[1], room, XDR_ENCODE);
    if (!proc (&x, (void *)in)) {
      FLUME_SET_ERRNO (FLUME_EXDR);
      rc = -1;
    } else {
      msgsize = xdr_getpos (&x);
      buf[0] = htonl (0x80000000 |  msgsize);
      rc = msgsize + sizeof (msgsize);
    }
    xdr_destroy (&x);
  }
  
  return rc;
}

int
c_str2xdr (void *out, xdrproc_t proc, const void *in, size_t len)
{
  const u_int32_t *buf = (u_int32_t *)in;
  XDR x;
  size_t sz;
  u_int32_t rawsz = ntohl (buf[0]);
  int rc;

  if (! (rawsz & 0x80000000) ) {
    FLUME_SET_ERRNO (FLUME_EINVAL);
    rc = -1;
  } else {
    sz = rawsz & 0x7fffffff;
    
    xdrmem_create (&x, (char *)&buf[1], len - sizeof (rawsz), XDR_DECODE);
    if (!proc (&x, out)) {
      FLUME_SET_ERRNO (FLUME_EXDR);
      rc = -1;
    } else if (xdr_getpos (&x) != sz) {
      FLUME_SET_ERRNO (FLUME_ETOOSMALL);
      rc = -1;
    } else {
      rc = 0;
    }
    xdr_destroy (&x);
  }

  return rc;
}
