// -*-c++-*-
#ifndef TMOINCLI_H
#define TMOINCLI_H

#include "async.h"
#include "basecli.h"

#define BUFLEN 128
#define LOCKED -2

typedef struct _tmoinuser_t {
  char uname[BUFLEN];
  char pw[BUFLEN];
  char uid[BUFLEN];
  char gid[BUFLEN];
  char tpw[BUFLEN];
} tmoinuser_t;

class tmoin_cli : public base_cli {
  
 public:
  tmoin_cli (int dummy=0);
  ~tmoin_cli ();

  virtual str get_req ();
  virtual int parse_resp (str resp);

  virtual base_cli *clone ();

  virtual str usage (str progname);
  virtual str cmd_name ();
  virtual int parse_args (int argc, char *argv[]);

 protected:
  /* These fields are one-per client thread */
  int page_suffix;
  int page_revision;
  int counter;

  static str userlist;
  static str path;
  static int suffix_range;
  static bool write_benchmark;
  static bool sequential_users;
  static bool sequential_read;
  static int initial_rev;
  static int write_size;
  static vec<int> current_revs;

  str make_random_text ();
  str make_const_text ();

  virtual void read_userlist (str path);
  virtual str make_path ();

  virtual str write_req ();
  virtual str read_req ();
  virtual str make_cookie ();

private:
  static vec<tmoinuser_t> users;

};

#endif /* MOINCLI_H */
