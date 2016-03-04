// -*-c++-*-
#include "async.h"
#include "flumedbg.h"
#include "parseopt.h"
#include "unixutil.h"
#include "flumeconst.h"
extern "C" { 
#include "sysflume_simple.h"
#include "flumeclnt_c.h"
}

#include "sess.h"

namespace sess {
  conn_t::conn_t (sess_srv_t *ss, int fd, const x_label_tc *S, const x_label_tc *I) :
    _ss (ss),
    _fd (fd),
    _client_Slabel (label_clone (S)),
    _client_Ilabel (label_clone (I)) { }

  conn_t::~conn_t () {
    label_free (_client_Slabel);
    label_free (_client_Ilabel);
  }
  
  void
  conn_t::handle_new_session (sess_msg_t *msg)
  {
    sess_id_t id = _ss->next_id ();
    assert (!_ss->get_session (id));

    sess_t *sess = New sess_t(id, _client_Slabel, _client_Ilabel);
    _ss->insert_session (sess);

    sess_msg_t reply;
    reply.msg_type = SESS_MSG_NEWSESS_RPL;
    reply.return_code = FLUME_OK;
    reply.sess_id = id;

    buf.tosuio ()->clear ();
    buf.tosuio ()->copy (&reply, sizeof(reply));
    fdcb (_fd, selwrite, wrap (mkref(this), &conn_t::write_data));
  }

  void
  conn_t::handle_save_session (sess_msg_t *msg)
  {
    sess_msg_t reply;
    bzero (&reply, sizeof(reply));
    reply.msg_type = SESS_MSG_SAVESESS_RPL;
    reply.return_code = FLUME_OK;
    reply.sess_id = msg->sess_id;

    sess_t *sess = _ss->get_session(msg->sess_id);

    // Check labels, (S_client [= S_session)
    // Check labels, (I_session [= I_client)
    if (!sess) {
      FLUMEDBG4 (SESS, CHATTER, "  save could not find sess %d\n", (int)msg->sess_id);
      reply.return_code = FLUME_ENOENT;
    } else if (!label_is_subset (_client_Slabel, sess->_Slabel)) {
      FLUMEDBG3 (SESS, CHATTER, "  save failed S label check\n");
      reply.return_code = FLUME_ENOENT;
    } else if (!label_is_subset (sess->_Ilabel, _client_Ilabel)) {
      FLUMEDBG3 (SESS, CHATTER, "  save failed I label check\n");
      reply.return_code = FLUME_EPERM;
    } else {
      FLUMEDBG4 (SESS, CHATTER, "  saving sess %d\n", (int)msg->sess_id);
      memcpy (sess->_sess_data, msg->buf, SESS_MAX_SIZE);
    }

    buf.tosuio ()->clear ();
    buf.tosuio ()->copy (&reply, sizeof(reply));
    fdcb (_fd, selwrite, wrap (mkref(this), &conn_t::write_data));
  }

  void
  conn_t::handle_get_session (sess_msg_t *msg)
  {
    sess_msg_t reply;
    bzero (&reply, sizeof(reply));
    reply.msg_type = SESS_MSG_GETSESS_RPL;
    reply.return_code = FLUME_OK;
    reply.sess_id = msg->sess_id;

    FLUMEDBG4 (SESS, CHATTER, "got req for session %d\n", (int)msg->sess_id);

    sess_t *sess = _ss->get_session(msg->sess_id);
    // Check labels, (S_session [= S_client)
    // Check labels, (I_client [= I_session)
    if (!sess) {
      FLUMEDBG4 (SESS, CHATTER, "  get could not find sess %d\n", (int)msg->sess_id);
      reply.return_code = FLUME_ENOENT;
    } else if (!label_is_subset (_client_Slabel, sess->_Slabel)) {
      FLUMEDBG3 (SESS, CHATTER, "  get failed S label check\n");
      reply.return_code = FLUME_ENOENT;
    } else if (!label_is_subset (_client_Ilabel, sess->_Ilabel)) {
      FLUMEDBG3 (SESS, CHATTER, "  get failed I label check\n");
      reply.return_code = FLUME_EPERM;
    } else {
      FLUMEDBG4 (SESS, CHATTER, "  sending sess %d\n", (int)msg->sess_id);
      memcpy (reply.buf, sess->_sess_data, SESS_MAX_SIZE);
    }

    buf.tosuio ()->clear ();
    buf.tosuio ()->copy (&reply, sizeof(reply));
    fdcb (_fd, selwrite, wrap (mkref(this), &conn_t::write_data));
  }

  void
  conn_t::write_data ()
  {
    FLUMEDBG4 (SESS, CHATTER, "write_data remaining bytes to send %d\n", 
             (int)buf.tosuio()->resid());
    int rc = buf.tosuio()->output (_fd);

    if (rc < 0 && rc != EAGAIN) {
      FLUMEDBG4 (SESS, ERROR, "errorA code %d, dropping connection\n", rc);
      close(_fd);
      fdcb (_fd, selwrite, NULL);
      return;

    } 

    if (buf.tosuio()->resid() == 0) {
      close(_fd);
      fdcb (_fd, selwrite, NULL);
      return;
    }
  }

  void
  conn_t::read_data ()
  {
    int rc = buf.tosuio()->input (_fd);

    if (rc < 0 && rc != EAGAIN) {
      FLUMEDBG4 (SESS, ERROR, "errorB code %d, dropping connection\n", rc);
      close(_fd);
      fdcb (_fd, selread, NULL);
      return;
    }

    if (buf.tosuio()->resid() == sizeof (sess_msg_t)) {
      sess_msg_t *msg = (sess_msg_t *) str(buf).cstr();
      FLUMEDBG4 (SESS, CHATTER, "got request type %d\n", msg->msg_type);

      switch (msg->msg_type) {
      case SESS_MSG_NEWSESS_REQ:
        handle_new_session (msg);
        break;
      case SESS_MSG_SAVESESS_REQ:
        handle_save_session (msg);
        break;
      case SESS_MSG_GETSESS_REQ:
        handle_get_session (msg);
        break;
      default:
        FLUMEDBG3 (SESS, ERROR, "invalid request type, ignoring\n");
      }
      
      fdcb (_fd, selread, NULL);
      return;
    }
  }
  
  sess_srv_t::sess_srv_t (str configfile, str rmsockfile) :
    _configfile (configfile),
    _rm_sock (rmsockfile),
    _srvfd (-1),
    _id_counter(1), // Valid session IDs must be non-zero.
    _rm_fd (-1)
  { }

  sess_srv_t::~sess_srv_t () { }

  sess_id_t
  sess_srv_t::next_id ()
  {
    return _id_counter++;
  }

  bool
  sess_srv_t::parseconfig (const str &cf)
  {
    FLUMEDBG4 (SESS, CHATTER, "using config file: %s\n", cf.cstr());
    parseargs pa (cf);
    bool errors = false;
    int line;
    vec<str> av;
    conftab ct;
  
    ct.add ("SessServerSocket", &_socket_file)
      .add ("UserGroupHandle", &_group_handle)
      .add ("UserGroupToken", &_group_token);

    while (pa.getline (&av, &line)) {
      if (!ct.match (av, cf, line, &errors)) {
        FLUMEDBG4 (SESS, ERROR, "%s:%d: unknown config parameter\n", 
                  cf.cstr(), line);
        errors = true;
      }
    }

    return !errors;
  }

  void
  sess_srv_t::socket_accept_client ()
  {
    int fd, rc;
    x_label_tc *S = label_alloc (0);
    x_label_tc *I = label_alloc (0);
    ptr<conn_t> conn;

    fd = flume_accept (_srvfd);
    if (fd < 0) {
      FLUMEDBG4 (SESS, ERROR, "error accepting connection errno %d, ignoring\n", 
                flume_errno);
      return;
    }

    rc = flume_get_fd_label (S, LABEL_S, fd);
    if (rc < 0) {
      FLUMEDBG4 (SESS, ERROR, "accepted client on fd %d, but could not "
               "query client's S label, ignoring client\n", fd);
      close (fd);
      goto cleanup;
    } 
    rc = flume_get_fd_label (I, LABEL_I, fd);
    if (rc < 0) {
      FLUMEDBG4 (SESS, ERROR, "accepted client on fd %d, but could not "
               "query client's I label, ignoring client\n", fd);
      close (fd);
      goto cleanup;
    } 
    
    if (FLUMEDBG2 (SESS)) {
      fprintf (stderr, "sess: ++ accepted client on fd %d S = ", fd);
      label_print (stderr, S);
      fprintf (stderr, " I = ");
      label_print (stderr, I);
      fprintf (stderr, "\n");
    }

    conn = New refcounted<conn_t>(this, fd, S, I);
    fdcb (fd, selread, wrap (conn, &conn_t::read_data));

  cleanup:
    label_free (S);
    label_free (I);
    return;
  }
  
  void
  sess_srv_t::rm_status_cb (hlp_status_t status)
  {
    switch (status) {
    case HLP_STATUS_NONE:
      break;

    case HLP_STATUS_OK:
      make_listen_sock ();
      break;

    case HLP_STATUS_CONNECTING:
    case HLP_STATUS_RETRY:
    case HLP_STATUS_ERR:
    case HLP_STATUS_HOSED:
    case HLP_STATUS_DENIED:
      close (_srvfd);
      fdcb (_srvfd, selread, NULL);
      break;
    }
  }

  void
  sess_srv_t::make_listen_sock ()
  {
    int rc;
    x_labelset_tc labs;
    bzero (&labs, sizeof (labs));

    /* socket file exists already? */
    rc = flume_stat_file (&labs, _socket_file);
    fprintf (stderr, "statfile returned %d %d\n", rc, flume_errno);
    if (rc == 0) {
      FLUMEDBG4 (SESS, CHATTER, "socket file %s exists, unlinking\n", 
                _socket_file.cstr());
        
      rc = flume_unlink (_socket_file);
      if (rc < 0) {
        FLUMEDBG4 (SESS, FATAL_ERROR, "error unlinking socket file %s\n", 
                  _socket_file.cstr());
        exit (1);
      }
    }

    /* Create a UNIX socket to listen on.  Only RM can connect to this
     * socket.  All processes must connect via RM or they must be
     * root. */
    labelset_clear (&labs);    
    _srvfd = flume_unixsocket (_socket_file, &labs); // mode 0600?
    if (_srvfd < 0) {
      FLUMEDBG4 (SESS, FATAL_ERROR, "error in FLUME_UNIXSOCKET: %d\n", flume_errno);
      exit (1);
    }

    /* Listen on the socket */
    rc = flume_listen (_srvfd, 5);
    if (rc < 0) { 
      FLUMEDBG4 (SESS, FATAL_ERROR, "Error from listen: %d\n", flume_errno);
      exit (1);
    } else {
      FLUMEDBG4 (SESS, CHATTER, "listening on socket %s\n", _socket_file.cstr());
      fdcb (_srvfd, selread, wrap (this, &sess_srv_t::socket_accept_client));
    }
  }

  void
  sess_srv_t::launch ()
  {
    int rc;
    str d;
    x_handle_tc g;

    if (!parseconfig (_configfile)) {
      FLUMEDBG4 (SESS, FATAL_ERROR, "%s: config file contains errors.\n", 
                _configfile.cstr());
      exit (1);
    }

    /* connect to RM */
    rc = flume_myctlsock ();
    if (rc < 0) {
      FLUMEDBG4 (SESS, FATAL_ERROR, "error connecting to RM socket %s\n", 
                _rm_sock.cstr());
      exit (1);
    }

    /* get capabilities */
    if (handle_from_str (_group_handle.cstr(), &g) < 0) {
      FLUMEDBG3 (SESS, FATAL_ERROR, "UserGroup is invalid, could not parse\n");
      exit (1);
    }
    FLUMEDBG4 (SESS, CHATTER, "requesting %llx token %s\n", 
              g, _group_token.cstr());
    rc = flume_req_privs (g, _group_token.cstr ());
    if (rc < 0) {
      FLUMEDBG4 (SESS, FATAL_ERROR, 
                "failed to get all user privileges, status is: %d\n", flume_errno);
      exit (1);
    }

    make_listen_sock ();
  }
};

static void
usage ()
{
  warnx << "usage: " << progname << " [-f <configfile>]\n";
  exit (1);
}

int
main (int argc, char *argv[])
{
  setprogname (argv[0]);
  set_debug_flags ();

  int ch;
  str configfile, rmsockfile;

  while ((ch = getopt (argc, argv, "f:s:")) != -1) {
    switch (ch) {
    case 'f':
      configfile = optarg;
      break;
    case 's':
      rmsockfile = optarg;
      break;
    default:
      usage ();
      break;
    }
  }

  if (configfile && !can_read (configfile)) {
    FLUMEDBG4 (SESS, FATAL_ERROR, "Cannot access config file for reading: %s\n",
              configfile.cstr());
    exit (1);
  }

  if (!configfile) 
    configfile = flume_etcfile_required (sess::config_filename_base);

  if (!configfile) {
    FLUMEDBG3 (SESS, FATAL_ERROR, "No configfile specified or found.\n");
    usage ();
  }

  if (!rmsockfile)
    rmsockfile = getenv("FLUME_RM_SOCKET");
  if (!rmsockfile) {
    FLUMEDBG3 (SESS, FATAL_ERROR, "you must define the rm socket, either use the "
             "-s option or the FLUME_RM_SOCKET environment variable\n");
    usage();
  }

  sess::sess_srv_t *sess_obj;
  sess_obj = New sess::sess_srv_t (configfile, rmsockfile);

  // We dont need to use BLOCK because we haven't called amain?
  sess_obj->launch (); 
  amain ();
}
