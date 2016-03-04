#include <sys/types.h>
#include <unistd.h>

int main (void) {
  int i, rc;
  pid_t pid;

  for (i=0; i<1000; i++){

    pid = fork ();
    if (pid) {
      wait (&rc);

    } else {
      execl ("/bin/sh", "/bin/sh", "empty", NULL);
      exit (0);
    }
  }
}
