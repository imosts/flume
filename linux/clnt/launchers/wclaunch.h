// -*-c++-*-
#ifndef WCLAUNCH_H
#define WCLAUNCH_H

#include "async.h"
#include "tame.h"


#define MODE_TRUSTED   "trusted"
#define MODE_STATIC    "static"
#define MODE_EXEC      "exec"
#define MODE_PYTHON    "python"

#define ARG_FNAME      "fname"
#define ARG_TEXT       "txarea"

#define ACTION_CONTROL    "control"
#define ACTION_UPLOAD     "upload"


class wclaunch {

 public:
  wclaunch () : page1_ls(NULL), page2_ls(NULL) {}
  ~wclaunch () {}

  void start (CLOSURE);

 protected:
  str request_uri, path_info;
  str req_mode, req_user, req_file; // parsed from URI
  str cookie_un, cookie_uid, cookie_gid, cookie_tpw;     // read from cookies
  x_labelset_t *page1_ls, *page2_ls;
  
  principal_t *_me;
  principal_hash_t _name2tags;

  void read_cookies ();
  int logged_in ();
  int parse_uri (str req);

  void handle_create (str un, str pw);
  void handle_login (str un, str pw);
  void send_upload_form ();
  void handle_upload ();
  void send_control_panel ();
  void handle_trusted ();

  void handle_static ();
  void handle_exec ();
  void handle_python (cbv cb, CLOSURE);
  x_labelset_t *script_labelset ();
};
#endif

