// -*-c++-*-
#ifndef BASECLI_H
#define BASECLI_H

#include "async.h"

class base_cli {
  /* ascli will create a new base_cli instance for each request to the server.
   * ascli will also create a single base_cli instance during startup.
   */

 public:
  base_cli (int dummy=0) : 
    nusers (0),
    noisy (false), 
    ERR (stderr)
  {}
  
  ~base_cli () {}

  virtual str get_req () = 0;

  /* Returns 0 if the response was ok
   * Returns -1 if there was something unexpected in the resp */
  virtual int parse_resp (str resp) = 0;

  virtual base_cli *clone () = 0;

  virtual str usage (str progname) = 0;
  virtual str cmd_name () = 0;

  /* returns -1 on failure */
  virtual int parse_args (int argc, char *argv[]) = 0;

  void set_noisy (bool noisy) { this->noisy = noisy; }
  void set_errout (FILE *err) { this->ERR = err; }

protected:
  int nusers;
  bool noisy;
  FILE *ERR;

  void clone_base (base_cli *c) {
    this->noisy = c->noisy;
    this->ERR = c->ERR;
  }
};

#endif /* BASECLI_H */
