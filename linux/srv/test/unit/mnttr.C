
#include "async.h"
#include "mounttree2.h"

int
main(int argc, char *argv[])
{
  mounttree2::root_t<int> tree;

  const char *dirs[] = { "/",
			 "/usr",
			 "/usr/local",
			 "/disk",
			 "/disk/a",
			 "/disk/a/b/c",
			 "/disk/b",
			 "/disk/e",
			 "/disk/a/b/f",
			 "/disk/a/a",
			 NULL };
  u_int i = 0;
  const char **p;
  for ( p = dirs ; *p; i++, p++) {
    tree.insert (*p, New refcounted<int> (i));
  }

  static rxx x ("/+");

  for (int i = 1 ; i < argc; i++) {
    str s = argv[i];
    vec<str> v;
    split (&v, x, s);
    if (v.size() && v[0].len() == 0) {
      v.pop_front ();
    }
    ptr<mounttree2::iterator_t<int> > it = tree.mk_iterator (v);
    warn << "Iterate: " << s << "\n";
    ptr<int> ip;
    str m, f;
    while ((ip = it->next (&m, &f))) {
      warn ("  %d %s %s\n", *ip, m.cstr(), f.cstr());
    }
  }
}
