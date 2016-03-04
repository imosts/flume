// -*-c++-*-

#include <sys/types.h>
#include <sys/socket.h>
#include "async.h"
#include "tame.h"
extern "C" { 
#include "sysflume_simple.h"
#include "flumeclnt_c.h"
}
#include "sess.h"


tamed static void
launch ()
{
  tvars {
    char session_data[SESS_MAX_SIZE];
    int fd, rc;
    sess_msg_t msg;
  }
  bzero (session_data, SESS_MAX_SIZE);
  strcpy (session_data, "Hello!!");

  // Request a new session
  fd = flume_unixsocket_connect_c ("/home/sesssock");
  if (fd < 0) {
    printf ("connect1 return code %d\n", fd);
    exit (1);
  }

  msg.msg_type = SESS_MSG_NEWSESS_REQ;

  rc = write (fd, &msg, sizeof(msg));
  if (rc != sizeof (msg)) {
    printf ("write return code %d\n", rc);
    exit (1);
  }

  bzero (&msg, sizeof(msg));
  rc = read (fd, &msg, sizeof(msg));
  if (rc != sizeof (msg)) {
    printf ("read1 return code %d\n", rc);
    exit (1);
  }
  
  close (fd);
  //fprintf (stderr, "got sess id %llx\n", msg.sess_id);


  // Save some data to our session
  fd = flume_unixsocket_connect_c ("/home/sesssock");
  if (fd < 0) {
    printf ("connect2 return code %d\n", fd);
    exit (1);
  }

  msg.msg_type = SESS_MSG_SAVESESS_REQ;
  // leave msg.sess_id unchanged
  bzero (msg.buf, SESS_MAX_SIZE);
  memcpy (msg.buf, session_data, SESS_MAX_SIZE);

  rc = write (fd, &msg, sizeof(msg));
  if (rc != sizeof (msg)) {
    printf ("write return code %d\n", rc);
    exit (1);
  }

  bzero (&msg, sizeof(msg));
  rc = read (fd, &msg, sizeof(msg));
  if (rc != sizeof (msg)) {
    printf ("read2 return code %d\n", rc);
    exit (1);
  }
  
  close (fd);


  // Retrieve our session data and check that it's correct.
  fd = flume_unixsocket_connect_c ("/home/sesssock");
  if (fd < 0) {
    printf ("connect3 return code %d\n", fd);
    exit (1);
  }

  msg.msg_type = SESS_MSG_GETSESS_REQ;
  // leave msg.sess_id unchanged
  bzero (msg.buf, SESS_MAX_SIZE);

  rc = write (fd, &msg, sizeof(msg));
  if (rc != sizeof (msg)) {
    printf ("write return code %d\n", rc);
    exit (1);
  }

  bzero (&msg, sizeof(msg));
  rc = read (fd, &msg, sizeof(msg));
  if (rc != sizeof (msg)) {
    printf ("read3 return code %d\n", rc);
    exit (1);
  }

  if (!memcmp (msg.buf, session_data, SESS_MAX_SIZE)) 
    printf ("PASS: session id 0x%016llx data is identical: %s\n", 
            msg.sess_id, msg.buf);
  else 
    printf ("FAIL: session id 0x%016llx data is not identical [%s] [%s] %d\n", 
            msg.sess_id, msg.buf, session_data, SESS_MAX_SIZE);
  
  close (fd);
  exit (0);
}

int main (int argc, char *argv[])
{
  launch ();
  amain ();
}
