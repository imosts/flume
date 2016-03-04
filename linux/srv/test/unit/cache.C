
#include "async.h"
#include "cache.h"

int main(int argc, char *argv[]) 
{
  cache::lru_t<int,int> l (5);

  for (int i = 0; i < 10; i++) {
    l.insert (i, i*2 + 1);
  }

  for (int j = 0; j < 2; j++) { 
    for (int i = 10; i >= 0; i--) {
      int *v = l.fetch (i);
      if (v) {
	warn ("%d => %d\n", i, *v);
      } else {
	warn ("%d => ()\n", i);
      }
    }
  }

}
