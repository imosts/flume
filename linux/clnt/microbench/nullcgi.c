#include "flume_features.h" // must come before <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>

#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/wait.h>
#include "flume_cpp.h"
#include "flume_prot.h"
#include "flume_api.h"
#include "flume_clnt.h"

int main (int argc, char *argv[]) {
  char *output = "Status: 200 OK\r\nContent-type: text/html\r\n\r\nnullcgi!";

  // Close the RPC socket to the launcher
  x_handle_t rpc_tok;
  int rpc_fd;
  if (handle_from_armor (getenv ("RPC_TAG"), &rpc_tok))
    return (-1);
  rpc_fd = flume_claim_socket (rpc_tok, "RPC socket");
  close (rpc_fd);

  /*
  fprintf (stdout, "Status: 200 OK\r\n");
  fprintf (stdout, "Content-type: text/html\r\n\r\n");
  fprintf (stdout, "nullcgi!");
  */
  
  // for some reason, printf doesn't work, so just use write ()
  write (1, output, strlen (output));
  return (0);
}
