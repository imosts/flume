
%#include "flume_prot.h"

typedef hyper cwd_tok_t;

enum fs_op_t { FS_OP_FDPASS       = 0x1,
               FS_OP_CREATE       = 0x2,
               FS_OP_WRITE        = 0x4,
               FS_OP_GETLABEL     = 0x8,
               FS_OP_PAIRWISE     = 0x10,
	       FS_OP_GETPATH	  = 0x20,
	       FS_OP_GETSTAT      = 0x40,
	       FS_OP_SAMEDIR 	  = 0x80,
	       FS_OP_GETFILTER    = 0x100
	};

struct file_arg_fs_t {
	file_c_arg_t  c_args;    /* from flume_prot.x */
	x_labelset_t proc;       /* additional: add the process label */
 	x_labelset_t *xls;       /* if creating, add this label */
	unsigned options;        /* flume internal options */
	cwd_tok_t cwd;           /* directory token */
	x_filterset_t filters;   /* currently active filters */
	x_handle_t *setuid_h;    /* handle for setuid protection */

	/* if creating, use this label for proc when writing parent dir */
	x_labelset_t *proc_parent_dir; 
};

union chdir_res_fs_t switch (flume_status_t status) {
case FLUME_OK:
	cwd_tok_t cwd;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

program FLUME_FS_PROG {

	version FLUME_FS_VERSION {

		void
		FLUME_FS_NULL(void) = 0;

		file_res_t
		FLUME_FS_OPEN(file_arg_fs_t) = 1;

		file_res_t
		FLUME_FS_STAT(file_arg_fs_t) = 2;

		file_res_t
		FLUME_FS_MKDIR(file_arg_fs_t) = 3;

		file_res_t
		FLUME_FS_UNIXSOCKET(file_arg_fs_t) = 4;

		file_res_t
		FLUME_FS_UNIXCONNECT(file_arg_fs_t) = 5;

		file_res_t
		FLUME_FS_RMDIR(file_arg_fs_t) = 6;

		file_res_t
		FLUME_FS_RENAME(file_arg_fs_t) = 7;

		file_res_t 
		FLUME_FS_UNLINK(file_arg_fs_t) = 8;

		file_res_t
		FLUME_FS_LINK(file_arg_fs_t) = 9;

		file_res_t
		FLUME_FS_SYMLINK(file_arg_fs_t) = 10;

		chdir_res_fs_t
		FLUME_FS_CHDIR(file_arg_fs_t) = 11;

		flume_status_t
		FLUME_FS_SHUTDOWN(cwd_tok_t) = 12;

		file_res_t
		FLUME_FS_FLUME_STAT(file_arg_fs_t) = 13;

		file_res_t 
		FLUME_FS_READLINK(file_arg_fs_t) = 14;

		file_res_t 
		FLUME_FS_LSTAT (file_arg_fs_t) = 15;

		file_res_t
		FLUME_FS_ACCESS (file_arg_fs_t) = 16;

		file_res_t
		FLUME_FS_UTIMES (file_arg_fs_t) = 17;

		file_res_t
		FLUME_FS_LUTIMES (file_arg_fs_t) = 18;

		file_res_t
		FLUME_FS_READ_FILTER (file_arg_fs_t) = 19;

		file_res_t
		FLUME_FS_WRITEFILE (file_arg_fs_t) = 20;

	} = 1;

} = 22223;
