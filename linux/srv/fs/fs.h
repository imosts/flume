
// -*-c++-*-

#ifndef _FS_FS_H_
#define _FS_FS_H_

#include "flume.h"
#include "tame.h"
#include "flume_prot.h"
#include "flume_fs_prot.h"
#include "flume_idd_prot.h"
#include "flume_ev_labels.h"
#include "unixutil.h"
#include "aiod.h"
#include "arpc.h"
#include "fsutil.h"
#include <sys/types.h>
#include <dirent.h>
#include "handlemgr.h"
#include "evalctx.h"
#include "tame_nlock.h"


namespace fs {

  typedef callback<void, int, str>::ref cbis_t;
  typedef callback<void, flume_status_t, DIR *>::ref opendir_cb_t;

  typedef tame::lock_table_t<ino_t> t_lock_table_t;
  typedef tame::lock_handle_t<ino_t> t_lock_handle_t;
  typedef tame::named_lock_t<ino_t> t_named_lock_t;

  typedef event<flume_status_t, ptr<t_lock_handle_t> >::ref acquire_cb_t;
  
  
  class base_srv_t : public jailable_t {
  public:
    base_srv_t (const cfg_t &o);
    virtual ~base_srv_t ();
    
    enum { READING = 0x1, 
	   WRITING = 0x2, 
	   EQUALS = 0x4, 
	   CREATE = 0x8,  
	   MKDIR = 0x10,
	   ALL_WRITES_OK = 0x20,
	   NOFILTER = 0x40,
	   SOCKET = 0x80
    };
    
    void run ();
    void init (cbb cb, CLOSURE);
    
  protected:
    void dispatch (svccb *sbp);
    void handle_open (svccb *sbp, CLOSURE);
    void handle_writefile (svccb *sbp, CLOSURE);
    void handle_read_filter (svccb *sbp, CLOSURE);
    void handle_unlink(svccb *sbp, CLOSURE);
    void handle_utimes (svccb *sbp, CLOSURE);
    void handle_lutimes (svccb *sbp, CLOSURE);
    void handle_mkdir (svccb *sbp, CLOSURE);
    void handle_rmdir (svccb *sbp, CLOSURE);
    void handle_stat (svccb *sbp, CLOSURE);
    void handle_unixsocket (svccb *sbp, CLOSURE);
    void handle_unixconnect (svccb *sbp, CLOSURE);
    void handle_rename (svccb *sbp, CLOSURE);
    void handle_link_or_rename (svccb *sbp, bool lnk, CLOSURE);
    void handle_symlink(svccb *sbp, CLOSURE);
    void handle_shutdown (svccb *sbp, CLOSURE);

    bool setuid ();

    void handle_open_existing (const file_arg_fs_t *arg, 
			       file_res_t *res,
			       cbi cb, int flags = -1,
			       ptr<eval::ctx_t> ctx = NULL,
			       CLOSURE);
    void handle_open_creat (const file_arg_fs_t *arg, 
			    file_res_t *res, cbi cb, CLOSURE);

    void stat_get_labels_by_fn (int dfd, ino_t ino, const str &fn, 
				file_res_t *res, cbv cb, 
				labelset_t *lsp, CLOSURE);

    void fswalk (const str &file, int flags, int mode,
		 const labelset_t *proc, flume_status_cb_t cb, int opts,
		 ptr<eval::ctx_t> ctx = NULL, CLOSURE);
    
    // implemented in terms of open_impl
    void open (const str &fn, int flags, int mode, cbi cbi, CLOSURE);
    void double_open (const str &dir, const str &file,
		      int *dfdp, int *fdp, flume_status_cb_t cb, CLOSURE);
    
    void check_unixconnect (const str &p, const labelset_t *proc,
			    str *fp, open_cb_t cb,
			    const filterset_t &fs, CLOSURE);

    // FS routines
    virtual void file2str (str fn, cbis_t cb) = 0;
    virtual void str2file (str f, str s, int mode, cbi cb) = 0;
    virtual void opendir (const str &fn, callback<void, DIR*>::ref cb) = 0;

    // Original method for checking paths had a EPERM/ENOENT covert
    // channel, so we should switch over to using open_impl instead
    virtual void open_impl (int fd, const str &fn, int flags, int mode,
			    open_cb_t cb, bool *fe_p = NULL) = 0;

    virtual void utimes_impl (int fd, x_utimes_t *xut, flume_status_cb_t) = 0;

    virtual void stat_impl (int fd, const str &fn, struct stat *sb,
			    flume_status_cb_t cb, bool use_lstat) = 0;
    virtual void readlink_impl (int fd, const str &fn, str *out,
				flume_status_cb_t cb) = 0;
    virtual void access_impl (int fd, const str &p, int m, 
			      flume_status_cb_t) = 0;
    virtual void writefile_impl (int fd, const str &s, flume_status_cb_t)= 0;

    virtual void open_for_stat_impl (int dfd, const str &f, open_cb_t cb) = 0;

    virtual void unlink_impl (int pdh, const str &fn, 
			      unlink_cb_t cb) = 0;

    virtual void mkdir_impl (int fd, const str &fn, int mode, 
			     open_cb_t cb) = 0;
    virtual void rmdir_impl (int fd, const str &fn, flume_status_cb_t cb) = 0;
    virtual void mksock_impl (int fd, const str &fn, int mode, 
			      open_cb_t cb, struct stat *sb) = 0;
    virtual void link_or_rename_impl (int fd, const str &to, const str &from,
				      bool lnk, flume_status_cb_t cb) = 0;

    virtual void symlink_impl (int fd, const str &to, const str &from,
			       flume_status_cb_t cb) = 0;

    virtual void unixconnect_impl (int fd, const str &fn, open_cb_t cb) = 0;

    virtual void get_frozen_labelset (int fd, frozen_labelset_t *ls,
				      flume_status_cb_t cb) = 0;

    virtual void get_frozen_labelset_by_fn (int dfd, const str &fn,
					    frozen_labelset_t *ls,
					    flume_status_cb_t cb) = 0;

    virtual void set_frozen_labelset (int fd, const frozen_labelset_t &S,
				      flume_status_cb_t cb) = 0;

    virtual void set_frozen_labelset_by_fn (int dfd, const str &fn,
					    const frozen_labelset_t &ls,
					    flume_status_cb_t cb) = 0;


    void get_labels (int fd, bool is_root,
		     labelset_t *ls, int which,
		     flume_status_cb_t cb, const str &fn, 
		     ptr<t_lock_handle_t> *lhp = NULL, 
		     tame::lock_t::mode_t lmode = tame::lock_t::SHARED, 
		     CLOSURE);

    void set_labels (int fd, const labelset_t *ls, int which,
		     flume_status_cb_t cb, const str &fn, int pfd, CLOSURE);

    void set_labels_by_fn (int dfd, ino_t ino, const str &fn,
			   const labelset_t *ls, int which,
			   flume_status_cb_t cb, CLOSURE);

    void label_from_fstr (const str &fstr, label_t *l, flume_status_t *st,
			  cbv cb, CLOSURE);

    void do_open (const file_arg_fs_t *arg, file_res_t *ret, cbi cb, CLOSURE);

    // XXX kludge -- should be virtualized like the others (and made
    // into an _impl function).
    void read_filter (const str &fn, int fd, file_res_t *res, cbv cb, 
		      CLOSURE);

    void thaw_label (const frozen_label_t *in, ptr<label_t> *out,
		     flume_status_t *res, cbv cb, CLOSURE);

    void thaw_labels (const frozen_labelset_t *in, labelset_t *out,
		      int which, flume_status_cb_t cb, CLOSURE);

    void freeze_label (const label_t *in, frozen_label_t *out,
		       flume_status_t *res, cbv cb, CLOSURE);

    void freeze_labels (const labelset_t *in, frozen_labelset_t *out,
			int which, flume_status_cb_t cb, CLOSURE);

    virtual bool v_init () { return true; }

    static int boil_down_flags (int unix_flags);
    
    void open_and_check (const str &f, int flags, int mode,
			 ptr<labelset_t> proc, 
			 const filterset_t &fs,
			 open_cb_t cb, 
			 int rw = READING | WRITING ,
			 ptr<labelset_t> vrfy = NULL,
			 ptr<t_lock_handle_t> *plh = NULL,
			 tame::lock_t::mode_t lmode = tame::lock_t::SHARED,
			 ptr<eval::ctx_t> ctx = NULL,
			 labelset_t *file = NULL,
			 CLOSURE);

    void prepare_create (const file_arg_fs_t *arg, 
			 file_res_t *res,
			 str *filep, int *pfdp, 
			 ptr<t_lock_handle_t> *plhp, 
			 ptr<labelset_t> *ls_creat, 
			 cbv cb, int opts = 0,
			 CLOSURE);

    void prepare_read (const str &path, str *dd_path_p, str *pd_d,
		       str *file_p, int *fd_d_p, flume_status_cb_t cb, 
		       CLOSURE);

    void prepare_modify (const file_arg_fs_t *arg, str *filep, 
			 int *pfdp, ptr<t_lock_handle_t> *plhp,
			 flume_status_cb_t cb, 
			 int opts = 0,
			 bool *in_root_p = NULL,
			 ptr<eval::ctx_t> ctx = NULL,
			 CLOSURE);
		       
    void
    creat_in (int pfd, const str &file, int flags, int mode,
	      ptr<labelset_t> creat, open_cb_t cb, CLOSURE);

    void
    mkdir_in (int pfd, const str &file, int mode,
	      const labelset_t *ls,
	      flume_status_cb_t cb, CLOSURE);

  protected:

    bool integrity_ns_check (const str &fn, const labelset_t &proc,
			     const labelset_t &file);
    bool is_integrity_fs_root (const str &fn);
    
    bool check_attrfile ();
    void shutdown ();
    bool check_deviceid ();

    void check_filename (const labelset_t *ls, const str &filename,
			 file_res_t *res, cbv cb, CLOSURE);

    void acquire_lock (int fd, const str &what, 
		       tame::lock_t::mode_t mode, acquire_cb_t cb, CLOSURE);
    void acquire_lock_by_name (const str &what, tame::lock_t::mode_t mode, 
			       acquire_cb_t cb, CLOSURE);
    void acquire_lock_by_ino (ino_t ino, tame::lock_t::mode_t mode,
			      acquire_cb_t cb, CLOSURE);

    // return the default labelset for this FS
    ptr<const labelset_t> def_ls ();

    str pathfix (const str &in) const;
    
    cfg_t _cfg;
    
    ptr<axprt_unix> _x;
    ptr<aclnt> _cli;
    ptr<asrv> _srv;

    t_lock_table_t _locks;
    dev_t _devid;
    str _rename_tmpdir, _lostfound_dir;

    u_int64_t _next_cwd_token;
    qhash<u_int64_t, int> _cwd_tokens;
    ptr<const labelset_t> _def_ls;
  };
  
  class aiod_srv_t : public base_srv_t {
  public:
    aiod_srv_t (const cfg_t &o);
    ~aiod_srv_t ();

    enum { blocksz = 0x4000 };

    void file2str (str fn, cbis_t cb) { file2str_T (fn, cb); }
    void str2file (str f, str s, int mode, cbi cb) 
    { str2file_T (f, s, mode, cb); }

  protected:
    bool v_init ();


  private:
    void file2str_T (str fn, cbis_t cb, CLOSURE);
    void str2file_T (str f, str s, int mode, cbi cb, CLOSURE);

    aiod *_aiod;
  };

  class simple_srv_t : public base_srv_t {
  public:
    simple_srv_t (const cfg_t &o);
    ~simple_srv_t ();
    void file2str (str fn, cbis_t cb) ;
    void str2file (str f, str s, int mode, cbi cb);

    void get_frozen_labelset (int fd, frozen_labelset_t *ls, 
			      flume_status_cb_t cb)
    { get_frozen_labelset_T (fd, ls, cb); }

    void set_frozen_labelset (int fd, const frozen_labelset_t &ls,
			      flume_status_cb_t cb)
    { set_frozen_labelset_T (fd, ls, cb); }

    void set_frozen_labelset_by_fn (int dfd, const str &fn, 
				    const frozen_labelset_t &ls, 
				    flume_status_cb_t cb)
    { set_frozen_labelset_by_fn_T (dfd, fn, ls, cb); }

    void get_frozen_labelset_by_fn (int dfd, const str &fn,
				    frozen_labelset_t *ls, 
				    flume_status_cb_t cb)
    { get_frozen_labelset_by_fn_T (dfd, fn, ls, cb); }

    void opendir (const str &fn, callback<void, DIR *>::ref cb);
    void writefile_impl (int fd, const str &s, flume_status_cb_t cb);

    void stat_impl (int fd, const str &fn, struct stat *sb,
		    flume_status_cb_t cb, bool use_lstat);
    void readlink_impl (int fd, const str &fn, str *out,
			flume_status_cb_t cb);
    void access_impl (int fd, const str &path, int mode, flume_status_cb_t cb);

    void open_impl (int fd, const str &fn, int flags, int mode,
		    open_cb_t cb, bool *fe_p = NULL);
    void utimes_impl (int fd, x_utimes_t *xut, flume_status_cb_t cb);
    void open_for_stat_impl (int dfd, const str &f, open_cb_t cb);
    void unlink_impl(int pdh, const str &f, unlink_cb_t cb);
    void mkdir_impl (int fd, const str &fn, int mode, open_cb_t cb);
    void mksock_impl (int fd, const str &fn, int mode, open_cb_t cb,
		      struct stat *sb);
    void unixconnect_impl (int fd, const str &fn, open_cb_t cb);
    void rmdir_impl (int fd, const str &fn, flume_status_cb_t cb);
    void link_or_rename_impl (int fd, const str &to, const str &from,
			      bool lnk, flume_status_cb_t cb);
    void symlink_impl (int fd, const str &to, const str &from,
		       flume_status_cb_t cb);
  private:
    void set_frozen_labelset_T (int fd, const frozen_labelset_t &ls,
				flume_status_cb_t cb, CLOSURE);

    void set_frozen_labelset_by_fn_T (int dfd, const str &fn, 
				      const frozen_labelset_t &ls, 
				      flume_status_cb_t cb, CLOSURE);

    void get_frozen_labelset_T (int fd, frozen_labelset_t *ls, 
				flume_status_cb_t cb, CLOSURE);
    
    void get_frozen_labelset_by_fn_T (int dfd, const str &fn,
				      frozen_labelset_t *ls, 
				      flume_status_cb_t cb, CLOSURE);
				      
  };

};
  
#endif /* _FS_FS_H_ */
