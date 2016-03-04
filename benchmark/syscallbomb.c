#include <sys/types.h>
#include <unistd.h>

int main (void) {
  long i;
  int rc;
  pid_t pid;
  struct timeval tv;

  for (i=0; i<1000000; i++){
    rc = gettimeofday (&tv, NULL);
  }
}
