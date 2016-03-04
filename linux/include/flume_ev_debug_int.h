
// -*-c++-*-
/* $Id: flumedbg-int.h 1682 2006-04-26 19:17:22Z max $ */

/*
 */

#ifndef _FLUME_DEBUG_INT_H
#define _FLUME_DEBUG_INT_H 1

#include "rxx.h"

typedef enum {
  CHATTER = 0,
  ERROR = 1,
  FATAL_ERROR = 2,
  SECURITY = 3
} flumedbg_lev_t;


#define FLUMEDBG(x) \
  (flume_debug_flags & (x))

#define FLUMEDBG2(x) \
  (flume_debug_flags & (FLUME_DEBUG_##x))

#define FLUMEDBG3(o,l,s) \
do { if (FLUMEDBG2(o)) { flumedbg_warn (l,s); } } while (0)

#define FLUMEDBG4(o,l,f,...) \
do { if (FLUMEDBG2(o)) { flumedbg_warn (l,f,__VA_ARGS__); } } while (0)

void flumedbg_warn (flumedbg_lev_t l, const str &s);

//
// provide __attribute__((format)) so that the compiler does sanity
// checking on the varargs lists, as it would for printf.
//
void flumedbg_warn (flumedbg_lev_t l, const char *fmt, ...)
  __attribute__ ((format (printf, 2, 3)));

class flumedbg_dumpable_t {
public:
  virtual ~flumedbg_dumpable_t () {}
  virtual void flumedbg_dump_vec (vec<str> *s) const = 0;
  virtual void flumedbg_dump (flumedbg_lev_t l = CHATTER) const 
  {
    vec<str> v;
    flumedbg_dump_vec (&v);
    for (u_int i = 0; i < v.size () ; i++) {
      flumedbg_warn (l, v[i]);
    }
  }

};

void set_debug_flags ();
extern u_int64_t flume_debug_flags;

#endif /* _FLUME_DEBUG_INT_H */
