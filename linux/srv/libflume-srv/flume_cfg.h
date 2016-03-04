
// -*-c++-*-

#ifndef _LIBFLUMESRV_FLUMECFG_H_
#define _LIBFLUMESRV_FLUMECFG_H_
#include "unixutil.h"
#include "qhash.h"

class base_cfg_t {
public:

  base_cfg_t () {}
  virtual ~base_cfg_t () {}

  bool setuid ();

  ptr<flume_usr_t> _user;
  ptr<flume_grp_t> _group;
  
};

str file2hash (const str &fn, struct stat *sbp = NULL);

class config_parser_t {
public:
  config_parser_t () {}
  virtual ~config_parser_t () {}
  bool run_configs (const str &fn);
  void include (vec<str> s, str loc, bool *errp);
protected:
  bool do_file (const str &fn);
  virtual bool parse_file (const str &fn) = 0;
  virtual bool post_config (const str &fn) { return true; }
private:
  bhash<str> _seen; // files seen
};


#endif /* _LIBFLUMESRV_FLUMECFG_H_ */
