// -*-c++-*-
#ifndef W5CLI_H
#define W5CLI_H

#include "async.h"
#include "basecli.h"

#define W5BUFLEN 512

#define W5CLI_LOGINPAGE "loginpage"
#define W5CLI_HOMEPAGE  "homepage"
#define W5CLI_BLOG      "blog"
#define W5CLI_ALBUM     "album"
#define W5CLI_DEBUG     "debug"
#define W5CLI_FASTCGITEST "fastcgitest"
#define W5CLI_NULLPY    "nullpy"
#define W5CLI_NULLC     "nullc"
#define W5CLI_APACHENULLC "apachenullc"
#define W5CLI_DJANGONULL "djangonull"
#define W5CLI_DJANGOALBUM "djangoalbum"

typedef struct _w5user_t {
  char un[W5BUFLEN];
  char gid[W5BUFLEN];
  char tpw[W5BUFLEN];
  char cid[W5BUFLEN];
  char http_host[W5BUFLEN];
  char base_url_exec[W5BUFLEN];
  char base_url_py[W5BUFLEN];
  char album_extension[W5BUFLEN];
} w5user_t;

class w5_cli : public base_cli {
  
 public:
  w5_cli (int dummy=0);
  ~w5_cli ();

  virtual str get_req ();
  virtual int parse_resp (str resp);

  virtual base_cli *clone ();

  virtual str usage (str progname);
  virtual str cmd_name ();
  virtual int parse_args (int argc, char *argv[]);

 protected:
  /* These fields are one-per client thread */
  int counter;
  w5user_t myuser;

  /* whole class config options */
  static str userlist;
  static bool write_benchmark;
  static str which_page;
  static int use_nusers;

  str make_random_text ();
  str make_const_text ();

  virtual void read_userlist (str path);
  virtual str make_path ();
  virtual str make_http_host ();

  virtual str write_req ();
  virtual str read_req ();
  virtual str make_cookie ();

private:
  static vec<w5user_t> users;

};

#endif /* W5CLI_H */
