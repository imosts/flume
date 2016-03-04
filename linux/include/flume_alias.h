
#ifndef _FLUME_ALIAS_H_
#define _FLUME_ALIAS_H_

//
// Stolen from plash's src/libc-comms.h
//

#define weak_extern(symbol) \
  extern typeof(symbol) symbol __attribute((weak));
#define weak_alias(name, aliasname) \
  extern int aliasname() __attribute ((weak, alias (#name)));

/* export_weak_alias() corresponds to weak_alias(),
   export_versioned_symbol() corresponds to versioned_symbol(), and
   export_compat_symbol() corresponds to compat_symbol()
   from glibc's include/shlib-compat.h. */

/* e.g. export(new_open, __open) */
#define export(name, aliasname) \
  extern int export_##aliasname() __attribute ((alias (#name)));

/* e.g. export_weak_alias(new_open, open) */
#define export_weak_alias(name, aliasname) \
  extern int export_##aliasname() __attribute ((weak, alias (#name)));

//
// Stolen from Linux headers
//
# define strong_alias(name, aliasname) _strong_alias(name, aliasname)
# define _strong_alias(name, aliasname) \
  extern __typeof (name) aliasname __attribute__ ((alias (#name)));

//
// Some ABI calls are linked to glibc version 2.2 symbols, which we hack
// in for now.
//
#define versioned_symbol(lib, from, to, version) \
     __asm__ (".symver " #from "," #to "@@" #version)


#define flume_all_aliases(x) \
  weak_alias (__##x, x) \
  weak_alias (__##x, __libc_##x) \
  weak_alias (__##x, __GI___##x) \
  weak_alias (__##x, __##x##_nocancel)

#endif /* _GLIBC_ALIAS_H_ */
