/*
 * A .x protocol file for flume communication
 */

/*
 * XDR-land representations for labels and handles; the local representation
 * of labels will probably look difference, hence the x_ prefix.
 */

%#include <limits.h>

typedef unsigned hyper x_handle_t;
typedef unsigned hyper x_caph_t;
//此处的<>是什么意思？？？
typedef x_handle_t x_label_t<>;
typedef x_label_t x_handlevec_t;
typedef unsigned handle_prefix_t;
typedef string nickname_t<>;
typedef string random_str_t<>;
typedef string endpoint_desc_t<>;

%#define HANDLE_SHIFT_BITS 56
%#define HANDLE_MASK 0x00ffffffffffffffULL

struct perm_error_t {
	string desc<>;
};

enum flume_status_t {
	FLUME_OK = 0,
	FLUME_EPERM = 1,
	FLUME_UNHANDLED = 2,
	FLUME_ENOENT = 3,
	FLUME_ENOTCONN = 4,
	FLUME_EGROUP = 5,
	FLUME_EPATH = 6,
	FLUME_ECONREFUSED = 7,
	FLUME_EATTR = 8,
	FLUME_EIDD = 9,
	FLUME_EPERSISTENCE = 10,
	FLUME_EHANDLE = 11,
	FLUME_ERPC = 12,
	FLUME_EDUPLICATE = 13,
	FLUME_EMANAGEMENT = 14,
	FLUME_EINVAL = 15,
	FLUME_EDEVICE = 16,
	FLUME_ERACE = 17,
	FLUME_LABEL_OK = 18,
	FLUME_FDPASS_OK = 19,
	FLUME_EAGAIN = 20,
	FLUME_EIO = 21,
	FLUME_FDPASS_OK_OPAQUE = 22,
	FLUME_ENOTEMPTY = 23,
	FLUME_EXDEV = 24,
	FLUME_PATH_OK = 25,
	FLUME_EMEM = 26,
	FLUME_ECAPABILITY = 27,
	FLUME_ERANGE = 28,
	FLUME_ENULL = 29,
	FLUME_EEXIST = 30,
	FLUME_EISDIR = 31,
	FLUME_INTEGRITY_NS_BAD_NAME = 32,
	FLUME_STAT_OK = 33,
	FLUME_PATH_LABEL_OK = 34,
	FLUME_EROFS = 35,
	FLUME_EEXPIRED = 36,
	FLUME_EFD = 37,
	FLUME_EFORK = 38,
	FLUME_ESPAWN = 39,
	FLUME_EZOMBIE = 40,
	FLUME_ESETUID = 41,
	FLUME_ETOKEN = 42,
	FLUME_FILTER_OK = 43,
	FLUME_ELABEL = 44,
	FLUME_EFILTER = 45,
	FLUME_ECHECKSUM = 46,
	FLUME_EXDR = 47,
	FLUME_ORPHANED_ENDPOINT = 48,
	FLUME_EDISAPPEARED = 49,
	FLUME_NONEMPTY_INTEGRITY = 50,
	FLUME_ECONFINE = 51,
	FLUME_ETOOSMALL = 52,

	/* Reasons why you can't change your secrecy label */
	FLUME_OPEN_WRITABLE_FILE = 60,
	FLUME_OPEN_PIPES_OR_SOCKETPAIRS = 61,
	FLUME_BAD_LABEL = 62,

        FLUME_ERR = 100	
};

enum frozen_label_typ_t {
	FROZEN_LABEL_BASE16 = 0,
	FROZEN_LABEL_BASE32 = 1,
	FROZEN_LABEL_BINARY = 2
};

enum handle_opt_t {
	HANDLE_OPT_PERSISTENT = 0x1,
	HANDLE_OPT_GROUP = 0x2,
	HANDLE_OPT_DEFAULT_ADD = 0x4,
	HANDLE_OPT_DEFAULT_SUBTRACT = 0x8,
	HANDLE_OPT_IDENTIFIER = 0x10
};

enum capability_opt_t {
	CAPABILITY_ADD = 0x20,
	CAPABILITY_SUBTRACT = 0x40,
	CAPABILITY_GROUP_SELECT = 0x60
};

enum label_type_t {
	LABEL_NONE = 0x0,
	LABEL_S = 0x1,
	LABEL_I = 0x2,
	LABEL_O = 0x4,
	LABEL_NO_O = 0x3,
	LABEL_ALL = 0x7
};

enum label_scope_t {
	LABEL_SCOPE_PROCESS = 0,
	LABEL_SCOPE_FD = 1
};

enum capability_flag_t {
	CAPABILITY_GRANT = 1,
	CAPABILITY_SHOW = 2,
	CAPABILITY_VERIFY = 4,
	CAPABILITY_TAKE = 8,
	CAPABILITY_CLEAN = 16
};

struct x_capability_op_t {
	x_caph_t 		handle;
	capability_flag_t 	level;
};

typedef capability_flag_t capability_flag_set_t<>;
typedef int x_int_set_t<>;

enum flume_child_state_t {
	FLUME_CHILD_ALIVE = 0,
	FLUME_CHILD_SPAWN_RETURNED = 0x1,
	FLUME_CHILD_DISAPPEARED = 0x2,
	FLUME_CHILD_EXITTED = 0x4,
	FLUME_CHILD_HARVESTED = 0x8
};

union flume_exit_status_t switch (flume_child_state_t status) {
case FLUME_CHILD_EXITTED:
	int exit_code;
default:
	void;
};

struct flume_exit_t {
	x_handle_t flmpid;
	flume_exit_status_t exit_status;
};

struct x_label_change_t {
	x_label_t		label;
	label_type_t		which;
};
typedef x_label_change_t x_label_change_set_t<>;

enum wait_typ_t {
	FLUME_WAIT_ANY = 0,
	FLUME_WAIT_ONE = 1
};

union flume_wait_which_t switch (wait_typ_t typ) {
case FLUME_WAIT_ANY:
	void;
case FLUME_WAIT_ONE:
	x_handle_t flmpid;
};

struct flume_wait_arg_t {
	flume_wait_which_t which;
	int options;
};

union flume_wait_res_t switch (flume_status_t status) {
case FLUME_OK:
	flume_exit_t exit;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
}; 

typedef int flume_pid32_t;

union getpid_res_t switch (flume_status_t status) {
case FLUME_OK:
	flume_pid32_t pid;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;

};

union label_specifiers_t switch (label_scope_t scope) {
case LABEL_SCOPE_PROCESS:
	void;
case LABEL_SCOPE_FD:
	int fd;
};

struct get_label_arg_t {
	label_type_t		type;
	label_specifiers_t	specifiers;
};

union get_label_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_label_t label;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

struct x_filter_t {
	x_label_t find;
	x_label_t replace;
};

typedef x_filter_t x_filtervec_t<>;

struct x_filterset_t {
	x_filtervec_t S;
	x_filtervec_t I;
};

enum setcmp_type_t { 	COMPARE_NONE = 0x0, 
       			COMPARE_ADD = 0x1, 
       			COMPARE_SUBTRACT = 0x2 } ;

struct subset_of_arg_t {
	x_label_t lhs;
	x_label_t rhs<>;
	setcmp_type_t typ;	
};


struct set_label_arg_t {
	get_label_arg_t	    which;
	x_label_t           new_label;
	bool                force;
};

typedef x_capability_op_t x_capability_op_set_t<>;

/*
 * Capability RPCs -- arguments and results
 */
struct send_capabilities_arg_t {
	int 	           dest_fd;
	x_capability_op_set_t capabilities;
};

union verify_capabilities_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_capability_op_set_t results;
default:
	void;
};

struct verify_capabilities_arg_t {
	int          		fd;
	capability_flag_t       ops_on_all;
   	x_capability_op_set_t        caps;
};

/*
 * Basic handle manipulation RPCs
 */
typedef string handle_name_t<>;

struct new_handle_arg_t {
	handle_name_t name;
	handle_prefix_t prefix;
};


union new_handle_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_handle_t base_h;
case FLUME_EPERM:
	perm_error_t eperm;
case FLUME_ERPC:
	int code;
default:
	void;
};

/*
 * Group RPCs - arguments and results
 */
typedef string group_name_t<>;

struct x_labelset_t {
     x_label_t  S;
     x_label_t  I;
     x_label_t  *O;  
};

union get_labelset_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_labelset_t labelset;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

enum endpoint_mode_t { EP_READ = 1,
		       EP_WRITE = 2,	
		       EP_RW = 3,
		       EP_MUTABLE = 4 } ;

struct x_endpoint_t {
	x_label_t *S;
	x_label_t *I;
	unsigned attributes;
	endpoint_desc_t desc;
};

typedef x_endpoint_t x_endpoint_set_t<>;

union get_ep_info_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_endpoint_set_t ok;
default:
	void;
};

struct new_group_arg_t {
	group_name_t name;
	x_labelset_t labels;
};

struct new_group_t {
	x_handle_t base_h;
};

union new_group_res_t switch (flume_status_t status) {
case FLUME_OK:
	new_group_t group;
case FLUME_EPERM:
	perm_error_t eperm;
case FLUME_ERPC:
	int code;
default:
	void;
};

enum group_operation_t {
	GROUP_OPERATION_ADD = 0,
	GROUP_OPERATION_SUBTRACT = 1
};

struct operate_on_group_arg_t {
	x_handle_t   	     group;
	group_operation_t    op;
	x_handlevec_t        terms;
};

union group_stat_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_labelset_t ls;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

struct group_stat_arg_t {
	x_handle_t group;
};

struct socket_args_t {
	int type;
	int protocol;
};

struct x_timeval_t {
	unsigned tv_sec;
	unsigned tv_usec;
};

struct x_utimes_t {
	x_timeval_t atime;
	x_timeval_t mtime;
};

%#define PATH_MAX_MINUS_ONE PATH_MAX-1

typedef string fs_path_t<PATH_MAX_MINUS_ONE>;

struct file_c_arg_t {
  fs_path_t path;
  int flags;
  int mode;
  fs_path_t *path_src;       /* for something like symlink/link */
  socket_args_t *sock;       /* for socket pairs */
  x_utimes_t *utimes;        /* for utimes */
  opaque           data<>;   /* data for writing to a file */
};

/* A generic FS Arg */
struct file_arg_t {
  file_c_arg_t     c_args;   /* args from the C API */
  x_label_t        *O_label; /* show these write capabilities on open */
  x_labelset_t     *xls;     /* if creating a file, apply this label;
			        if reading, use as a Verify label */
  x_labelset_t     *ep;      /* what the label on the new EP should be */
}; 

struct apply_filter_arg_t {
	fs_path_t path;
	label_type_t which;
};


union set_ambient_fs_authority_arg_t switch (bool clear) {
case FALSE:
	x_label_t newvalue;
case TRUE:
	void;
};

struct login_arg_t {
        int pid;
        bool attach_systrace;
};

/* login tokens are the result of a 20-byte SHA1 hash */
%#define SHA1SZ 20
%#define BINTOKSZ SHA1SZ
typedef opaque priv_tok_bin_t[BINTOKSZ];
typedef string priv_tok_str_t<>;

enum priv_tok_typ_t {
	PRIV_TOK_NONE = 0,
	PRIV_TOK_BINARY = 1,
	PRIV_TOK_STR = 2
};

union priv_tok_t switch (priv_tok_typ_t typ)
{
case PRIV_TOK_NONE:
	void;
case PRIV_TOK_BINARY:
	priv_tok_bin_t bintok;
case PRIV_TOK_STR:
	priv_tok_str_t strtok;
};

typedef flume_status_t req_privs_res_t;

struct make_login_arg_t  {
	x_handle_t  	handle;
	unsigned	duration;
	bool 		fixed;
	priv_tok_typ_t	desired_tok_typ;
};

union make_login_res_t switch (flume_status_t status)
{
case FLUME_OK:
	priv_tok_t token;
case FLUME_EPERM:
	perm_error_t eperm;
case FLUME_ERPC:
	int rpcerror;
default:
	void;
};

struct req_privs_arg_t {
	priv_tok_t token;
	x_handle_t handle;
};

struct x_filter_file_t {
	x_filter_t filter;
	req_privs_arg_t *req_privs;
};

struct x_stat_t {
	unsigned dev;
	unsigned ino;
	unsigned mode;
	unsigned nlink;
	unsigned uid;
	unsigned gid;
	unsigned rdev;
	unsigned atime;
	unsigned mtime;
	unsigned ctime;
	unsigned hyper size;
	hyper blocks;
	unsigned blksize;
	unsigned flags;
	unsigned gen;
};

struct fs_path_label_t {
	fs_path_t path;
	x_labelset_t label;
};

struct file_fdpass_t {
	int fd;
	x_labelset_t label;
};

union file_res_t switch (flume_status_t status)
{
case FLUME_LABEL_OK:
	x_labelset_t label;
case FLUME_FDPASS_OK:
	file_fdpass_t fdpass_ok;
case FLUME_FDPASS_OK_OPAQUE:
	x_handle_t opaque_h;
case FLUME_ERPC:
	int error;
case FLUME_PATH_OK:
	fs_path_t path;
case FLUME_PATH_LABEL_OK:
	fs_path_label_t path_label;
case FLUME_STAT_OK:
	x_stat_t stat;
case FLUME_EPERM:
	perm_error_t eperm;
case FLUME_FILTER_OK:
	x_filter_file_t filter;
default:
	void;
};

enum duplex_t { DUPLEX_NONE = 0x0,
		DUPLEX_THEM_TO_ME = 0x1,
		DUPLEX_ME_TO_THEM = 0x2,
		DUPLEX_FULL = 0x3 };

struct pipe_arg_t {
	bool writing;
	endpoint_desc_t desc;
};

struct claim_arg_t {
	x_handle_t token;
	endpoint_desc_t desc;
};

struct pipe_handle_pair_t {
	x_handle_t my_end;
	x_handle_t their_end;
};

union socket_res_t switch (flume_status_t status){
case FLUME_OK:
	x_handle_t my_end;
default:
	void;
};

union pipe_res_t switch (flume_status_t status) {
case FLUME_OK:
	pipe_handle_pair_t hpair;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

struct claim_ok_t {
	x_handle_t opaque_h;
	duplex_t duplex;
};

union claim_res_t switch (flume_status_t status) {
case FLUME_OK:
	claim_ok_t ok;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

struct socketpair_arg_t {
	int domain;
	int type;
	int protocol;
	endpoint_desc_t desc;
};

struct register_fd_arg_t {
	x_handle_t rm_side;        /* needs to be crypto-protected */
	int        proc_side;
	bool       p2p;            /* either p2p or p2s */
};

struct listen_arg_t {
	int fd;
	int queue_len;
};

struct pid_arg_t {
  int pid;
};

typedef unsigned hyper frozen_label_t;

struct frozen_labelset_t {
	frozen_label_t S;
	frozen_label_t I;
	frozen_label_t O;
};

struct flume_extattr_t {
	frozen_labelset_t ls;
	opaque hash[SHA1SZ];		
};

union freeze_label_res_t switch (flume_status_t status) {
case FLUME_OK:
	frozen_label_t frozen;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

union thaw_label_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_label_t thawed;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

enum ynm_t {
	YNM_NO = 0,
	YNM_YES = 1,
	YNM_MAYBE = 2 
};

struct new_nickname_arg_t {
	nickname_t nickname;
	x_handle_t handle;
};

typedef fs_path_t fs_path_vec_t<>;

struct spawn_c_arg_t {
	fs_path_t cmd;
	fs_path_vec_t argv;
	fs_path_vec_t env;
	fs_path_t wd;
};

enum spawn_opt_t { SPAWN_SETUID = 0x1, SPAWN_CONFINED = 0x2 };

struct spawn_arg_t {
	spawn_c_arg_t c_args;
	spawn_opt_t opts;
	x_label_change_set_t label_changes;
        x_handlevec_t *claim_fds;
	x_label_t *I_min;
	x_endpoint_t *endpoint;
	x_endpoint_t *ch_endpoint;
};

struct spawn_res_ok_t {
	x_handle_t flmpid;
	int flmpid32;
};

struct kill_arg_t {
	x_handle_t flmpid;
	int sig;	
};

union spawn_res_t switch (flume_status_t status) {
case FLUME_OK:
case FLUME_EDISAPPEARED:
	spawn_res_ok_t ok;
case FLUME_EPERM:
	perm_error_t eperm;
case FLUME_ERPC:
	int rpcerr;
default:
	void;
};

union get_setuid_h_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_handle_t h;
case FLUME_EPERM:
	perm_error_t eperm;
default:
	void;
};

union flume_res_t switch (flume_status_t status) {
case FLUME_EPERM:
	perm_error_t eperm;
case FLUME_ERPC:
	int rpcerror;
default:
	void;

};

struct closed_files_arg_t {
	int ctlsock;
};

struct connect_arg_t {
  int              fd;       /* client's socket fd in client addr space */
  file_c_arg_t     c_args;   /* args from the C API */
  x_label_t        *O_label; /* show these write capabilities on open */
  x_labelset_t     *ep;      /* what the label on the new EP should be */
}; 

struct flume_dup_arg_t {
       int fd_orig;
       int fd_copy;
};

struct str2labelset_arg_t {
  string s<>;
};

union str2labelset_res_t switch (flume_status_t status) {
case FLUME_OK:
	x_labelset_t labelset;
default:
	void;
};

struct flume_confine_me_arg_t {
       int ctlsock;
};

struct flume_finish_fork_arg_t {
       int ctlsock;
       int unix_pid;
       int confined;
};

enum flume_ep_opt_which_t {    
     FLUME_EP_OPT_STRICT = 1,
     FLUME_EP_OPT_FIX = 2 
};

union flume_ep_opt_t switch (flume_ep_opt_which_t typ) {
case FLUME_EP_OPT_STRICT:
        bool strict;
default:
	void;
};

struct flume_setepopt_arg_t {
       int fd;
       flume_ep_opt_t opt;
};

struct debug_arg_t {
  string s<>;
};

program FLUME_PROG {
	version FLUME_VERS {

		void
		FLUME_NULL (void) = 0;
	
		flume_res_t 
		SET_LABEL(set_label_arg_t) = 1;

		new_handle_res_t
		NEW_HANDLE(new_handle_arg_t) = 2;

		/*
		 * Manage groups
		 */
		new_group_res_t 
		NEW_GROUP(new_group_arg_t) = 3;
		
		flume_res_t
		OPERATE_ON_GROUP(operate_on_group_arg_t) = 4;
	
		/*
		 * Manipulate/transfer capabilities
		 */
		flume_status_t
		SEND_CAPABILITIES(send_capabilities_arg_t) = 5;

		verify_capabilities_res_t
		VERIFY_CAPABILITIES(verify_capabilities_arg_t) = 6;

		flume_status_t
		SET_AMBIENT_FS_AUTHORITY(set_ambient_fs_authority_arg_t) = 7;

		get_label_res_t
		GET_LABEL (get_label_arg_t) = 8;

		make_login_res_t
		MAKE_LOGIN (make_login_arg_t) = 9;

       		str2labelset_res_t
		FLUME_FILENAME_TO_LABELSET(str2labelset_arg_t) = 10;

		new_handle_res_t
		LOOKUP_HANDLE_BY_NICKNAME(nickname_t) = 11;

		
    /*
     * Opening files
     */ 
    file_res_t 
    OPEN_FILE(file_arg_t) = 12;

		void FLUME_DEBUG_MSG (debug_arg_t) = 13;

		file_res_t
		FLUME_STAT_FILE(file_arg_t) = 14;

		file_res_t	
		FLUME_MKDIR(file_arg_t) = 15;

		file_res_t	
		FLUME_UNIXSOCKET(file_arg_t) = 16;

		flume_status_t
		FLUME_REGISTER_FD(register_fd_arg_t) = 17;

		flume_status_t
		FLUME_LISTEN(listen_arg_t) = 18;

		void
		DEAD_RPC_11(void) = 19;

		pipe_res_t
		FLUME_PIPE(pipe_arg_t) = 20;

		pipe_res_t
		FLUME_SOCKETPAIR(socketpair_arg_t) = 21;

		claim_res_t
		FLUME_CLAIM_FD(claim_arg_t) = 22;

		file_res_t
		FLUME_RMDIR(file_arg_t) = 23;

		file_res_t
		FLUME_RENAME(file_arg_t) = 24;

		file_res_t
		FLUME_UNLINK_FILE(file_arg_t) = 25;

		file_res_t
		FLUME_LINK(file_arg_t) = 26;

		file_res_t
		FLUME_SYMLINK(file_arg_t) = 27;

		file_res_t
		FLUME_CHDIR(file_arg_t) = 28;

		fs_path_t	
		FLUME_GETCWD(void) = 29;

		bool
		FLUME_DEBUG_DISABLE_EP_BOTTOM(void) = 30;

		flume_status_t 
		FLUME_FAKE_CONFINEMENT(bool) = 31;

		bool 
		FLUME_GET_CONFINED(void) = 32;

		void DEAD_RPC_33(void) = 33;
		void DEAD_RPC_34(void) = 34;

    		req_privs_res_t
    		REQ_PRIVS (req_privs_arg_t) = 35;

		group_stat_res_t
		FLUME_STAT_GROUP(group_stat_arg_t) = 36;	

		freeze_label_res_t
		FLUME_FREEZE_LABEL(x_label_t) = 37;

		thaw_label_res_t 
		FLUME_THAW_LABEL(frozen_label_t) = 38;

		flume_status_t
		FLUME_NEW_NICKNAME(new_nickname_arg_t) = 39;

		void DEAD_RPC_40(void) = 40;

		flume_status_t
		FLUME_CLOSE(int) = 41;

		file_res_t
		FLUME_FLUME_STAT_FILE(file_arg_t) = 42;

		file_res_t
		FLUME_READLINK(file_arg_t) = 43;

		int	
		FLUME_SUBSET_OF(subset_of_arg_t) = 44;

		file_res_t
		FLUME_LSTAT_FILE (file_arg_t) = 45;

		file_res_t
		FLUME_ACCESS_FILE (file_arg_t) = 46;

		random_str_t
		GENERATE_RANDOM_STR (unsigned) = 47;

		get_setuid_h_res_t
		FLUME_GET_SETUID_H (void) = 48;

		spawn_res_t
		FLUME_SPAWN(spawn_arg_t) = 49;

		void DEAD_RPC_50(void) = 50;

		flume_wait_res_t
		FLUME_WAIT(flume_wait_arg_t) = 51;

		file_res_t
		FLUME_UTIMES(file_arg_t) = 52;

		file_res_t
		FLUME_LUTIMES(file_arg_t) = 53;

		flume_status_t
		FLUME_DUP_CTL_SOCK(void) = 54;	

		file_res_t
		FLUME_LABELSET_TO_FILENAME(x_labelset_t) = 55;

		file_res_t
		FLUME_APPLY_FILTER(apply_filter_arg_t) = 56;

		file_res_t
		FLUME_WRITEFILE(file_arg_t) = 57;

		flume_status_t
		FLUME_KILL(kill_arg_t) = 58;

		get_ep_info_res_t
		FLUME_GET_ENDPOINT_INFO(void) = 59;

		get_labelset_res_t
		FLUME_GET_LABELSET (void) = 60;

                flume_status_t
                FLUME_CLOSED_FILES (closed_files_arg_t) = 61;

		getpid_res_t
		FLUME_GETPID(void) = 62;

                file_res_t
                FLUME_SOCKET(void) = 63;

                flume_status_t
                FLUME_CONNECT(connect_arg_t) = 64;

		bool
		FLUME_CHECK_ENDPOINT(x_endpoint_t) = 65;

		flume_status_t
		FLUME_DUP(flume_dup_arg_t) = 66;

		flume_status_t		   
		FLUME_CONFINE_ME(flume_confine_me_arg_t) = 67;

		flume_status_t
		FLUME_FINISH_FORK(flume_finish_fork_arg_t) = 68;

		flume_status_t
		FLUME_SETEPOPT(flume_setepopt_arg_t) = 69;
	} = 1;
} = 22222;

