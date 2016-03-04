
// -*-c++-*-

#ifndef _LIBFLUME_FLUMECONST_H_
#define _LIBFLUME_FLUMECONST_H_

#include "async.h"

extern const char *flume_etc_dir1;
extern const char *flume_etc_dir2;
extern const char *flume_etc_dir3;
extern size_t flume_ps;

extern const char *flume_dbg_attach_env_var;

str flume_etcfile (const char *f);
str flume_etcfile_required (const char *f);

namespace rm {

  extern const char *socket_file;
  extern const char *systrace_file;
  extern const char *config_filename_base;
  extern const char *topdir;
  extern u_int socket_file_mode;
};

namespace fs {
  extern const char *default_username;
  extern const char *default_groupname;
  extern const char *default_attrfile;
  extern int default_naiods;
  extern size_t default_aiod_shmsize;
  extern size_t default_aiod_maxbuf;
  extern size_t attr_size_per_file;
  extern const char * labelset_attrname;
  extern size_t max_writefile_size;
  extern size_t default_n_proc;
};

namespace idd {
  extern const char *config_filename_base;
  extern int default_port;

  extern ssize_t default_frz_cache_size;
  extern ssize_t default_thw_cache_size;
  extern ssize_t default_member_of_cache_size;
  extern ssize_t default_gea_cache_size;
};

namespace flmspwn {
  extern const char *default_username;
  extern const char *default_groupname;
  extern const char *default_ld_library_path;
  extern const char *default_linker;
  extern const char *default_group;
  extern const char *default_user;
  extern const char *default_dir;
};

namespace sess {
  extern const char *config_filename_base;
};

#endif /* _LIBFLUME_FLUMECONST_H_ */
