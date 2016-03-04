

// -*-c++-*-

#ifndef _SPAWN_SPAWN_H_
#define _SPAWN_SPAWN_H_

#include "async.h"
#include "crypt.h"
#include "arpc.h"

#include "flume.h"
#include "tame.h"
#include "flume_prot.h"
#include "flume_fs_prot.h"
#include "flume_idd_prot.h"
#include "flume_spawn_prot.h"
#include "flume_ev_labels.h"
#include "unixutil.h"
#include "aiod.h"
#include "arpc.h"
#include "spawnutil.h"
#include <sys/types.h>
#include <dirent.h>
#include "handlemgr.h"
#include "rxx.h"


namespace flmspwn {

  handle_t getflmpid ();

  class rpc_argv_t : public argv_t {
  public:
    template<size_t m, size_t n> 
    rpc_argv_t (const rpc_vec<rpc_str<m>, n>  &v, 
		const char *const *seed = NULL) 
    {
      vec<str> v2;
      for (size_t i = 0; i < v.size (); i++) {
	v2.push_back (v[i]);
      }
      init (v2, seed);
    }
  };

  class env_t {
  public:
    template<class V>
    env_t (const V &v, const char *const *seed = NULL) 
    {
      if (seed) {
	for (const char *const *p = seed; *p; p++) {
	  insert (*p);
	}
      }
      for (size_t i = 0; i < v.size (); i++) {
	insert (v[i]);
      }
    }
    void insert (const str &s);
    void set (const str &k, const str &v);
    ptr<argv_t> to_argv () const ;

  private:
    qhash<str,str> _map;
  };

  struct setuid_file_t {
  public:
    setuid_file_t (const str &p) : _path (p) {}
    void read (int fd, file_res_t *res);
    bool verify () const;

    vec<str> _argv;
    const str _path;
    ptr<handle_t> _h;
    str _token;
    ptr<handle_t> _I_frozen;
  };

  struct fd_t {
    fd_t (int f, bool ko, bool dereg, const str &s) : 
      _fd (f), _keep_open (ko), _dereg (dereg), _desc (s),
      _full_desc (strbuf ("%s fd=%d", _desc.cstr (), f)) {}

    const char *desc () const { return _full_desc.cstr (); }

    ihash_entry<fd_t> _hlnk;
    tailq_entry<fd_t> _qlnk;
    int _fd;
    bool _keep_open;
    bool _dereg;
    str _desc;
    str _full_desc;
  };

  struct fdtab_t {
  public:
    fdtab_t () : _minfd (-1) {}

    void insert (int i, bool keep_open, bool dereg, const str &desc);
    void insert (fd_t *fd);
    void hold_places (int maxfd, int openfd);

    int copy_up (int fd, int minfd);
    void close (fd_t *obj, int del = true);
    void remove (fd_t *obj);
    void close (int fd);
    void close_all ();
  private:
    int _minfd;
    ihash<int, fd_t, &fd_t::_fd, &fd_t::_hlnk> _tab;
    tailq<fd_t, &fd_t::_qlnk> _lst;
  };

  class spawner_t : public jailable_t {
  public:
    spawner_t (const cfg_t &o);
    ~spawner_t () ;

    void init (cbb cb, CLOSURE);
    void run ();
    void dispatch (svccb *sb);
    void shutdown ();

    void open (const str &fn, file_res_t *res, cbi cb, CLOSURE);

  protected:
    void handle_spawn (svccb *sbp, CLOSURE);
    void do_spawn (const spawn_i_arg_t *arg, spawn_i_res_t *res,
		   int _ctl_fd, cbv cb, CLOSURE);

    void do_execve (const str &cmd, const vec<str> &argv, ptr<argv_t> env);

    void do_spawn_child (const spawn_i_arg_t *arg, int ctlfd, int parentfd,
			 CLOSURE);
    void do_spawn_parent (pid_t pid, int tmpfd, spawn_i_res_t *res, cbv cb,
			  CLOSURE);

    void do_setuid (const spawn_i_arg_t &arg, str *cmd,
		    vec<str> *argv, file_res_t *res, cbv cb, CLOSURE);

    void do_label_changes (const spawn_i_arg_t &arg,
			   file_res_t *res, evv_t ev, CLOSURE);

    void do_label_change (const x_label_change_t &ls, 
			  file_res_t *res,
			  evb_t ev, CLOSURE);

    void set_I_label (const handle_t &fl, file_res_t *res, cbv cb, 
		      ptr<label_t> *new_I_p, CLOSURE);
    void setuid_login (handle_t h, const str &tok, file_res_t *res, cbv cb,
		       CLOSURE);
    void get_label_2 (label_type_t typ, ptr<label_t> *out, 
		    file_res_t *res, cbv cb, CLOSURE);
    void set_label (label_type_t typ, ptr<const label_t> in,
		    file_res_t *res, const char *desc, cbv cb, CLOSURE);
    void get_label_1 (label_type_t typ, x_label_t *out,
		      file_res_t *res, cbv cb, CLOSURE);
    void raise_S (const handle_t &h, ptr<label_t> *old_S,
		  file_res_t *res, cbv cb, CLOSURE);
    void claim_fd (x_handle_t h, cbi cb, int n = -1, CLOSURE);

    void verify_I_label (const x_label_t *I_min_x,
			 ptr<const label_t> I_new, file_res_t *res);


  private:
    cfg_t _cfg;
    
    ptr<axprt_unix> _x;
    ptr<aclnt> _cli;
    ptr<asrv> _srv;
    fdtab_t _open_fds;
    bool _in_child;
  };
};

#define N_STD_FDS 3
  
#endif /* _SPAWN_SPAWN_H_ */
