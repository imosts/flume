
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/wait.h>

int main(int argc, char *argv[])
{
  int flags = MAP_ANONYMOUS;

  if (argc == 2 && strcmp (argv[1], "-s") == 0) {
    flags |= MAP_SHARED;
  } else {
    flags |= MAP_PRIVATE;
  }

  const char *msg = "hello dude";
  size_t len = 4096;
  void *addr = mmap (NULL, len, PROT_WRITE, flags, -1, 0);

  printf ("mmap region is %p\n", addr);
  memcpy (addr, msg, strlen (msg) + 1);
  int rc = mprotect (addr, len, PROT_READ);
  if (rc != 0) {
    printf ("mprotect failed: %d\n", errno);
  }

  if (fork()) {
    int rc = mprotect (addr, len, PROT_WRITE);
    if (rc != 0) {
      printf ("mprotect failed: %d\n", errno);
    }
    const char *msg2 = "bye dude!";
    sleep (1);
    memcpy (addr, msg2, strlen (msg2) + 1);
    wait (&flags);

  } else {
    printf ("%p: %s\n", addr, (char *)addr);
    sleep (2);
    printf ("%p: %s\n", addr, (char *)addr);
  }

  return 0;
}
