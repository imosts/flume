
#include "async.h"
#include "arpc.h"
#include "tst_prot.h"
#include "tame.h"

tamed static void
run_client (int fd)
{
  tvars {
    holdvar ptr<axprt_stream> x (axprt_stream::alloc (fd));
    ptr<aclnt> cli (aclnt::alloc (x, test_prog_1));
    int i;
	int y;
    clnt_stat err;
	int n (10000);
  }
  warn << "Making " << n << " RPCS\n";
  make_async (fd);
  for (i = 0; i < n; i++) {
    twait { cli->call (TEST_PING, &i, &y, mkevent (err)); }
	if (err) {
		fatal << "WTF!! " << err << "\n";
	}	
  }
  exit (0);
}

ptr<axprt_stream> sx;
ptr<asrv> sc;

static void
dispatch (svccb *sbp)
{
  int x;
  if (!sbp) {
    wait (&x);
    exit (0);
  }

  switch (sbp->proc ()) {
  case TEST_PING:
    {
      int *a = sbp->Xtmpl getarg<int> ();
      int r = *a + 1;
      sbp->replyref (r);
      break;
    }
  default:
    panic ("fooo\n");
    break;
  }

}


static void
run_server (int fd)
{
  make_async (fd);
  sx = axprt_stream::alloc (fd);
  sc = asrv::alloc (sx, test_prog_1, wrap (dispatch));
}

int 
main (int argc, char *argv[])
{
  int fds[2];
  socketpair (AF_UNIX, SOCK_STREAM, 0, fds);
  if (fork ()) {
    close (fds[1]);
    run_client (fds[0]);
  } else {
    close (fds[0]);
    run_server (fds[1]);
  }
  amain ();
}
