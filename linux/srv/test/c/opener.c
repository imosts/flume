
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>

void usage ()
{
	fprintf (stderr, "opener <file>\n");
	exit (0);
}

int
main (int argc, char *argv[])
{
	int i;
	int fd;
	int n = 10000;
	if (argc != 2) {
		usage ();
	}
	fprintf (stderr, "opening %d times\n", n);
	for (i = 0; i < n; i++) {
		if ((fd = open (argv[1], O_RDONLY)) < 0 && i == 0) {
			fprintf (stderr, "Couldn't open file.\n");
		} else {
		  close (fd);
		}
	}
  	return (0);
}
