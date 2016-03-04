
#include "flume_srv_const.h"
#include "sfsmisc.h"


const char *flume_etc_dir1 = "/usr/local/etc/flume";
const char *flume_etc_dir2 = "/usr/local/flume/conf";
const char *flume_etc_dir3 = "/etc/flume";

const char *flume_dbg_attach_env_var = "FLUME_DEBUG_ATTACH";

const char *flume_cfg_path[] = { flume_etc_dir1, flume_etc_dir2, flume_etc_dir3,
				etc1dir, etc2dir, etc3dir, NULL };

size_t flume_ps = 0x10000;

str flume_etcfile (const char *f) 
{ return sfsconst_etcfile (f, flume_cfg_path); }

str flume_etcfile_required (const char *f) 
{ return sfsconst_etcfile_required (f, flume_cfg_path); }


namespace rm {
  const char *systrace_file = "/dev/systrace";
  const char *socket_file = "/tmp/flumerm-sock";
  const char *config_filename_base = "flumerm.conf";
  const char *topdir = "/usr/local/lib/flume";
  u_int socket_file_mode = 0777;
};

namespace fs {
  const char *default_username = "nobody";
  const char *default_groupname = "nobody";
  const char *default_attrfile = ".flume_extattr";
  int default_naiods = 1;
  size_t default_aiod_shmsize = 0x200000;
  size_t default_aiod_maxbuf = 0x1000;
  size_t attr_size_per_file = 32;
  const char * labelset_attrname = "flmls";
  size_t max_writefile_size = 0x1000;
  size_t default_n_proc = 1;
};

namespace flmspwn {
  const char *default_ld_library_path = "/usr/local/lib/flume/shared";
  const char *default_linker = "/lib/ld-linux.so.2";
  const char *default_username = "nobody";
  const char *default_groupname = "nobody";
  const char *default_dir = "/var/tmp";
};

namespace idd {

  const char *config_filename_base = "idd.conf";
  int default_port = 42143;

  ssize_t default_frz_cache_size = 0x1000;
  ssize_t default_thw_cache_size = 0x1000;
  ssize_t default_member_of_cache_size = 0x1000;
  ssize_t default_gea_cache_size = 0x1000;
};

namespace sess {
  const char *config_filename_base = "sess.conf";
};


