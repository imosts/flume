// -*-c++-*-
#ifndef MOINCLI_H
#define MOINCLI_H

#include "async.h"
#include "tmoincli.h"

typedef struct _moinuser_t {
  char uname[BUFLEN];
  char pw[BUFLEN];
  char moinid[BUFLEN];
} moinuser_t;

class moin_cli : public tmoin_cli {
  
 public:
  moin_cli (int dummy=0);
  ~moin_cli ();

  virtual base_cli *clone ();

  str cmd_name ();

 protected:
  /* These fields are one-per client thread */

  virtual void read_userlist (str path);
  virtual str make_cookie ();

private:
  static vec<moinuser_t> musers;
};

#endif /* MOINCLI_H */
