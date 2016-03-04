#ifndef _FLUMECLNT_C_H_
#define _FLUMECLNT_C_H_

#ifdef FLUME_EVENT_CODE
# error "Cannot include this file from within Flume event code"
#endif

/**
 * This file contains functions that untrusted programs
 * might want to call.
 */
#include <stdlib.h>
#include <stdio.h>

#include "flume_prot.h"

/*
 * Full version of open, with all bells and whistles
 */
int
flume_open_full (char *outpath, const char *path, int flags, int mode, 
		x_labelset_t *ls, x_labelset_t *ep);

/*
 * Slightly less full version of open, in which the user can
 * specify a new labelset to apply to the file (ls) in the case
 * of file creation. Also specify which labelset to apply to the 
 * new endpoint (ep) that will be allocated.
 */
int
flume_open (const char *path, int flags, int mode, x_labelset_t *ls,
	   x_labelset_t *ep);

/*
 * Full version of symlink, in which the user can supply the label
 * to apply to the symlink (though this might be depricated, since the
 * label of the symlink might now be determined by the parent
 * directory).
 */
int 
flume_symlink_full (const char* contents, const char* newfile,
		   const x_labelset_t *ls);

/**
 * @brief Ask the reference monitor to make a new handle.
 * @param result The resulting handle if successful
 * @param opts Options to apply when making the handle (see flume_prot.x)
 * @param name The local name for the handle.
 * @return 0 if success, and <0 with an error code if failure.
 */
int flume_new_handle (x_handle_t *result, int opts, const char *name);

/**
 * returns 0 on success, and non-zero on failure.
 */
int flume_make_login (x_handle_t h, u_int exp, char fixed, char **out_token);

/**
 * make a new group with the given name and label 
 */
int flume_new_group (x_handle_t *res, const char *name, 
		    const x_labelset_t *ls);

/**
 * stat a group to figure out what its label is
 */
int flume_stat_group (x_labelset_t *out, x_handle_t g);

/**
 * Add a handle to a group
 */
int flume_add_to_group (x_handle_t group, x_handlevec_t *newhandles);

/**
 * stat a file on the FS to get the flume status of it.
 */
int flume_stat_file (x_labelset_t *out, const char *fn);

/**
 * do a setuid exec, flume style
 */
int flume_setuid_tag (x_handle_t *tc);

int flume_waitpid (x_handle_t *pidout, int *visible,
		   int *error_code, x_handle_t flmpid, 
		   int options);

#define SPAWN_OK  0
#define SPAWN_DISAPPEARED 1
/**
 * @brief spawn a new process.
 * @param flmpd output the created flmpd via this field
 * @param argv  the argument vector to spawn.
 * @param env   the environment variables to set.
 * @param opts  options to set, such as 'setuid' or 'confined'
 * @param claim_fds an array of pipe tokens to claim.
 * @param label_changes Perform this series of label changes in the child.
 * @param I_min Minimum integrity to run at.
 * @param endpoint Labels on endpoint for receiving exit signals, for PARENT
 * @param endpoint Labels on endpoint for sending signals, for CHILD
 * @return SPAWN_OK if spawn succeeds and process is visible, 
 *         SPAWN_DISAPPEARED if spawn succeeds and process is not visible
 *         < 0 on failure.
 */
int flume_spawn (x_handle_t *flmpid, 
		 const char *cmd, 
		 char *const argv[], 
		 char *const env[], 
		 int opts,
		 const x_handlevec_t *claim_fds,
		 const x_label_change_set_t *label_changes,
		 const x_label_t *I_min,
		 const x_endpoint_t *endpoint,
		 const x_endpoint_t *ch_endpoint);

int flume_spawn_legacy (x_handle_t *flmpid, 
			const char *cmd, 
			char *const argv[], 
			char *const env[], 
			int confined,
			int opts,
			const x_labelset_t *new_ls,
			const x_handlevec_t *claim_fds,
			const x_label_t *I_min);

int flume_kill (x_handle_t pid, int sig);

/*
 * create and write a file in one fell swoop
 */
int flume_writefile (const char *path, int flags, int mode,
		    const x_labelset_t *ls, const char *buf, size_t bsz);

/*
 * apply a filter off the file system; return what the filter is.
 */
int flume_apply_filter (x_filter_t *out, const char *path, 
		       label_type_t which);

/**
 * req_privs now takes a human-readly str, which the RM later
 * hashes down for us.
 */
int flume_req_privs (x_handle_t h, const char *token);

int flume_make_nickname (x_handle_t h, const char *n);
int flume_lookup_by_nickname (x_handle_t *h, const char *n);

/**
 * lookup info on this process's endpoints in the RM
 */
int flume_get_endpoint_info (x_endpoint_set_t *out);

/**
 * Try to add <h> to caller's secrecy label.
 */
int flume_expand_label (label_type_t type, x_handle_t h);

int flume_get_label (x_label_t *out, label_type_t typ);
int flume_get_fd_label (x_label_t *out, label_type_t typ, int fd);
int flume_set_label (const x_label_t *in, label_type_t typ, int force);
int flume_set_fd_label (const x_label_t *in, 
		       label_type_t typ, int fd);
int flume_subset_of (const x_label_t *l, const x_label_t *r, int len,
		    setcmp_type_t typ);
int flume_get_labelset (x_labelset_t *out);

/* set the options on the given ep/fd 
 */
int flume_setepopt (int fd, int op, int val);

int flume_shrink_label (label_type_t type, x_handle_t h);

int flume_freeze_label (frozen_label_t *out, const x_label_t *in);
int flume_thaw_label (x_label_t *out, const frozen_label_t *in);

int flume_unixsocket (const char *path, x_labelset_t *ls);
int flume_listen (int fd, int queue_len);
int flume_unixsocket_connect_c (const char *path);
int flume_accept (int fd);

int flume_mkdir_full (const char *path, mode_t mode, x_labelset_t *tc);

int flume_socketpair (int duplex_mode, int *myfd, x_handle_t *theirtoken,
		     const char *desc);
int flume_claim_socket (x_handle_t theirtoken, const char *desc);

int flume_closed_files ();
int flume_filename_to_labelset (const char *filename, x_labelset_t *out);

/*
 * make sure to free the result!
 */
char *flume_random_str (int n);

char *flume_labelset_to_filename (const x_labelset_t *in);

/*
 * pass capabilities from one proc to another (the guy on the other
 * side of the fd.  For each capability, specify a level to pass that
 * cap with.
 */
int flume_send_capabilities (int fd, const x_capability_op_set_t *caps);

/*
 * Verify (or collect) passed capabilities.  Pass in an fd to operate
 * over, an operation to apply to all capabilities, and the capabilities
 * to operate on (each with a flag, too, perhaps).  Write results to
 * the output set given.
 */
int flume_verify_capabilities (int fd, capability_flag_t ops_on_all,
			       const x_capability_op_set_t *in,
			       x_capability_op_set_t *out);

/*
 * called by the child to finish up the fork operation
 */
int flume_finish_fork (int fd, pid_t pid, int confined);

int flume_fork (int nfds, const int close_fds[], int confined);

/*
 * Data structure interface for manipulating labels in other languages
 */

#define XDR_MAXSZ (0x2400 + sizeof (u_int32_t))

ssize_t c_xdr2str (char *out, size_t outsz, xdrproc_t proc, const void *in);
int c_str2xdr (void *out, xdrproc_t proc, const void *in, size_t len);


x_handle_t handle_construct (handle_prefix_t prfx, x_handle_t base);
handle_prefix_t handle_prefix (x_handle_t h);
x_handle_t handle_base (x_handle_t b);
int handle_from_str (const char *s, x_handle_t *h);
int handle_from_armor (const char *s, x_handle_t *h);
int handle_from_raw (x_handle_t *out, const void *d, size_t l);
char *handle_to_raw (const x_handle_t *in, size_t *szp);
ssize_t handle_to_raw_static (void *out, size_t lim, const x_handle_t *x);
x_caph_t capability_construct (int prfx, x_handle_t handle);

int label_set (x_label_t *l, u_int off, x_handle_t h);
int label_contains (const x_label_t *lab, x_handle_t h);
int label_is_subset (const x_label_t *x, const x_label_t *y);
void label_print (FILE *s, x_label_t *lab);
void label_print2 (FILE *s, const char *prefix, x_label_t *lab);

x_labelset_t *labelset_alloc (void);
x_endpoint_t *endpoint_alloc (void);
int labelset_copy (x_labelset_t *out, const x_labelset_t *in);
int endpoint_copy (x_endpoint_t *out, const x_endpoint_t *in);
const char *endpoint_get_desc (x_endpoint_t *out);
void labelset_clear (x_labelset_t *ls);
void endpoint_clear (x_endpoint_t *ep);
int labelset_set_S (x_labelset_t *ls, const x_label_t *s);
int labelset_set_I (x_labelset_t *ls, const x_label_t *s);
int labelset_set_O (x_labelset_t *ls, const x_label_t *s);
char *labelset_to_raw (const x_labelset_t *in, size_t *szp);
ssize_t labelset_to_raw_static (void *, size_t , const x_labelset_t *);
int labelset_from_raw (x_labelset_t *out, const void *d, size_t l);
int endpoint_set_S (x_endpoint_t *e, const x_label_t *l);
int endpoint_set_I (x_endpoint_t *e, const x_label_t *l);

x_label_t *labelset_get_S (x_labelset_t *ls);
x_label_t *endpoint_get_S (x_endpoint_t *ep);
x_label_t *labelset_get_I (x_labelset_t *ls);
x_label_t *endpoint_get_I (x_endpoint_t *ep);
x_label_t *labelset_get_O (x_labelset_t *ls);
int labelset_alloc_O (x_labelset_t *ls, u_int sz);
void labelset_free (x_labelset_t *ls);
void endpoint_free (x_endpoint_t *ep);
void labelset_print (FILE *s, const char *prefix, x_labelset_t *ls);
void endpoint_set_attributes (x_endpoint_t *ep, u_int a);
u_int endpoint_get_attributes (x_endpoint_t *ep);

x_label_change_t *label_change_alloc ();
void label_change_clear (x_label_change_t *x);
void label_change_free (x_label_change_t *x);
int label_change_set_label (x_label_change_t *x, const x_label_t *l);
int label_change_copy (x_label_change_t *out, const x_label_change_t *in);
x_label_t *label_change_get_label (x_label_change_t *x);
int label_change_get_which (const x_label_change_t *x) ;
int label_change_set_which (x_label_change_t *x, int i);
x_label_change_t *label_change_clone (const x_label_change_t *in);

x_endpoint_set_t * endpoint_set_alloc (u_int sz); 

x_filter_t *filter_alloc ();
void filter_free (x_filter_t *f);
int filter_copy (x_filter_t *out, const x_filter_t *in);

/* routines from armor.c */
char * armor32_c (const void *dp, size_t dl, size_t *outlen);
size_t armor32len_c (const u_char *s);
char * dearmor32_c (const char *_s, ssize_t len, size_t *outlen);

void capability_op_clear (x_capability_op_t *x);
int capability_op_copy (x_capability_op_t *out, const x_capability_op_t *in);
void handle_clear (x_handle_t *x);
void int_clear (int *i);
int handle_copy (x_handle_t *out, const x_handle_t *in);
int int_copy (int *out, const int *in);


#define ARRAY_DO_DECLS(typ, prfx, elem)					\
  typ * prfx##_alloc (u_int sz);					\
  int prfx##_resize (typ *l, u_int sz, int cp);				\
  void prfx##_free(typ *l);						\
  u_int prfx##_size (const typ *l);					\
  void prfx##_init (typ *l);						\
  elem * prfx##_getp (typ *l, u_int off);				\
  void prfx##_clear (typ *l);						\
  typ * prfx##_clone (const typ *in);					\
  int prfx##_copy (typ *out, const typ *in);				\
  char *prfx##_to_raw (const typ *in, size_t *sz);			\
  ssize_t prfx##_to_raw_static (void *out, size_t sz, const typ *in);	\
  int prfx##_from_raw (typ *out, const void *in, size_t sz); 

ARRAY_DO_DECLS(x_label_t, label, x_handle_t);
ARRAY_DO_DECLS(x_endpoint_set_t, endpoint_set, x_endpoint_t);
ARRAY_DO_DECLS(x_label_change_set_t, label_change_set, x_label_change_t);
ARRAY_DO_DECLS(x_capability_op_set_t, capability_op_set, x_capability_op_t);
ARRAY_DO_DECLS(x_int_set_t, int_set, int);

#undef ARRAY_DO_DECLS


#endif /* _FLUMECLNT_C_H_ */
