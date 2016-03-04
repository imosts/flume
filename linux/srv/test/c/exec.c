
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

int
main (int argc, char *argv[])
{
  int sz = argc * sizeof (char *);
  char **nav = (char **)malloc (sz);
  char **a;

  memset (nav, 0, sz);
  memcpy (nav, argv + 1, sz - sizeof (char *));

  printf ("exec '%s'; argv:\n", nav[0]);
  for (a = nav; *a; a++) {
    printf ("\t%s\n", *a);
  }

  execve (nav[0], nav, NULL);
  return (0);
}
