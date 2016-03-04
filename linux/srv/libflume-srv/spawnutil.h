// -*-c++-*-

#ifndef _LIBFLUME_SPAWNUTIL_H_
#define _LIBFLUME_SPAWNUTIL_H_

#include "async.h"
#include "arpc.h"
#include "flume_prot.h"
#include "flume_ev_labels.h"
#include "flume_srv_const.h"
#include "unixutil.h"
#include "tame.h"
#include "flume_fs_prot.h"
#include "iddutil.h"
#include "flume_idd_prot.h"
#include "flume_spawn_prot.h"
#include "flume_cfg.h"


namespace flmspwn {
  struct cfg_t : public base_cfg_t {
    cfg_t ();
    
    bool parseopts (int argc, char *const argv[], str loc);
    bool to_argv (vec<str> *argv) const;
    void init ();

    str to_str () const;

    ptr<argv_t> _env;
    str _ld_library_path;
    str _linker;
    str _prog;
    str _chroot_dir;
  };

  void res2res (const spawn_i_res_t &ires, spawn_res_t *res);
  void arg2arg (const spawn_arg_t &res, spawn_i_arg_t *arg);
  void res2res (const flume_res_t &in, file_res_t *out);
};

#endif /* _LIBFLUME_SPAWNUTIL_H_ */
