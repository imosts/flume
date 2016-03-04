// -*-c++-*-
#ifndef TRAZCART_H
#define TRAZCART_H

#include "async.h"
#include "basecli.h"


typedef struct _user_t {
  char h[128];
  char token_str[128];
  int cart_id;
} user_t;


class trazcart_cli : public virtual base_cli {
  
 public:
  trazcart_cli (int dummy=0);
  ~trazcart_cli ();

  str get_req ();
  int parse_resp (str resp);

  base_cli *clone ();

  str usage (str progname);
  str cmd_name ();
  int parse_args (int argc, char *argv[]);

 protected:
  /* These fields are one-per client thread */
  int user_idx;
  bool tried_cookie;

  void read_userlist (str path);
  int parse_cookie (str s);
};

#endif /* TRAZCART_H */
