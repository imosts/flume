// -*-c++-*-
#ifndef _SESS_H_
#define _SESS_H_

#include "async.h"
#include "ihash.h"
#include "tame.h"
#include "pslave.h"
#include "sesstypes.h"

/**
 *  Talking to the session server:
 *    1) Client does unixconnect to socket file such as /tmp/sesssock
 *    2) Client writes bytes of a sess_msg to the socket.
 *    3) Client calls shutdown(2) on the fd, sending EOF to sess server.
 *    4) Server sends back a sess_msg back to the client
 *    5) Server closes its end of the socket.
 *    6) Client reads the sess_msg from the socket.
 */

namespace sess {

  class sess_srv_t;

  class sess_t {
  public:
    sess_id_t _sess_id;
    char _sess_data[SESS_MAX_SIZE];
    x_label_tc *_Slabel;
    x_label_tc *_Ilabel;

    ihash_entry<sess_t> _id_lnk;
    
    sess_t (sess_id_t id, const x_label_tc *S, const x_label_tc *I) : 
      _sess_id (id),
      _Slabel (label_clone (S)),
      _Ilabel (label_clone (I)) {}

    ~sess_t () { 
      label_free (_Slabel); 
      label_free (_Ilabel); 
    }
  };

  class conn_t : public virtual refcount {
  public:
    conn_t (sess_srv_t *ss, int fd, const x_label_tc *S, const x_label_tc *I);
    ~conn_t ();
    void read_data ();
    void write_data ();

  protected:
    sess_srv_t *_ss;
    int _fd;
    strbuf buf;
    x_label_tc *_client_Slabel;
    x_label_tc *_client_Ilabel;
    
    void handle_new_session (sess_msg_t *msg);
    void handle_save_session (sess_msg_t *msg);
    void handle_get_session (sess_msg_t *msg);
  };
  /* ----------------------------------------------------------- */

  class sess_srv_t {

  public:
    sess_srv_t (str configfile, str sockname);
    ~sess_srv_t ();
    void launch ();
    void socket_accept_client ();
    sess_id_t next_id ();
    void insert_session (sess_t *sess) { _sess_table.insert (sess); }
    void remove_session (sess_t *sess) { _sess_table.remove (sess); }
    sess_t *get_session (sess_id_t id) { return _sess_table[id]; }

    void sess_srv_t::rm_status_cb (hlp_status_t status);

  protected:
    str _configfile;
    str _rm_sock;

    str _socket_file;
    int _srvfd;
    sess_id_t _id_counter;
    int _rm_fd;
    ihash<sess_id_t, sess_t, &sess_t::_sess_id, &sess_t::_id_lnk> _sess_table;

    str _group_handle;
    str _group_token;

    bool parseconfig (const str &cf);
    void make_listen_sock ();
  };
};

#endif /* _SESS_H_ */
