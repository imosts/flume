
#include "flume_features.h"

#include <stdlib.h>
#include <limits.h>
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/time.h>
#include "flume_prot.h"
#include <errno.h>
#include <assert.h>
#include <inttypes.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <unistd.h>

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_clnt.h"
#include "flume_internal.h"


#define CLEAR(x) memset (&x, 0, sizeof (x))

void 
free_file_res(file_res_t *res)
{
  xdr_free ((xdrproc_t) xdr_file_res_t, (char *) res);
}

extern char **environ;

static void
argv2pathvec (char *const argv[], fs_path_vec_t *pv)
{
  char *const *ap;
  int i;
  for (ap = argv; *ap; ap++) { pv->len ++; }
  pv->val = (fs_path_t *)malloc (pv->len * sizeof (fs_path_t));
  for (i = 0, ap = argv; *ap; ap++, i++) {
    pv->val[i] = *ap;
  }
}

static void
my_num2env (const char *k, int d)
{
  char buf[32];
  sprintf (buf, "%d", d);
  setenv (k, buf, 1);
}

void
set_ctl_socket_env ()
{
  my_num2env (FLUME_SCK_EV, flume_myctlsock ());
}

int
flume_req_privs (x_handle_t h, const char *tok) 
{
  req_privs_arg_t arg;
  req_privs_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);

  if (!(handle_prefix(h) & HANDLE_OPT_PERSISTENT)) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
	     "flume_req_privs: cannot req privs for non-persistent handle\n");
    FLUME_SET_ERRNO (FLUME_EPERSISTENCE);
  } else {
    arg.handle = h;
    arg.token.typ = PRIV_TOK_STR;
    arg.token.u.strtok = (char *)tok;

    if (rpc_call (REQ_PRIVS, &arg, &res, "req_privs") < 0) {
      /* noop */
    } else if (res == FLUME_OK) {
      rc = 0;
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_req_privs: got privilege %" PRIx64 "\n", arg.handle); 
    } else {
      FLUME_SET_ERRNO (res);
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		   "flume_req_privs: error %d\n", rc); 
    }
  }
  return rc;
}

int
flume_get_endpoint_info (x_endpoint_set_t *out)
{
  get_ep_info_res_t res;
  int rc = -1;
  CLEAR(res);

  if (rpc_call (FLUME_GET_ENDPOINT_INFO, NULL, &res, "get_endpoint_info") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_SET_ERRNO (res.status);
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"get_endpoint_info: Error response: %d\n", res.status);
  } else {
    rc = endpoint_set_copy (out, &res.u.ok);
  }
  xdr_free ((xdrproc_t) xdr_get_ep_info_res_t , (char *)&res);
  return rc;
}

static int
get_label_common (x_label_t *out, get_label_arg_t *arg)
{
  get_label_res_t get_res;
  int rc = -1;

  CLEAR (get_res);

  if (rpc_call (GET_LABEL, arg, &get_res, "get_label") < 0) {
    /* noop */
  } else if (get_res.status != FLUME_OK) {
    FLUME_SET_ERRNO_UNION(get_res);
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_get_label: Error response: %d\n", rc);
  } else {
    rc = label_copy (out, &get_res.u.label);
  }

  xdr_free ((xdrproc_t) xdr_get_label_res_t, (char *) &get_res);
  return rc;
}

int 
flume_get_label (x_label_t *out, label_type_t typ)
{
  get_label_arg_t get_arg;
  CLEAR (get_arg);

  get_arg.type = typ;
  get_arg.specifiers.scope = LABEL_SCOPE_PROCESS;
  return get_label_common (out, &get_arg);
}

int
flume_get_labelset (x_labelset_t *out)
{
  get_labelset_res_t get_res;
  int rc = -1;
  CLEAR (get_res);

  if (rpc_call (FLUME_GET_LABELSET, NULL, &get_res, "get_labelset") < 0) {
    /* noop */
  } else if (get_res.status != FLUME_OK) {
    FLUME_SET_ERRNO_UNION(get_res);
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"flume_get_labelset: Error response: %d\n", rc);
  } else {
    rc = labelset_copy (out, &get_res.u.labelset);
  }
  xdr_free ((xdrproc_t )xdr_get_labelset_res_t, (char *) &get_res);
  return rc;
}

int 
flume_get_fd_label (x_label_t *out, label_type_t typ, int fd)
{
  get_label_arg_t get_arg;
  CLEAR (get_arg);

  get_arg.type = typ;
  get_arg.specifiers.scope = LABEL_SCOPE_FD;
  get_arg.specifiers.u.fd = fd;
  return get_label_common (out, &get_arg);
}

static int 
set_label_common (set_label_arg_t *arg)
{
  int rc = -1;
  flume_res_t res;
  CLEAR (res);

  if (rpc_call (SET_LABEL, arg, &res, "set_label") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_SET_ERRNO_UNION (res);
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_set_label: Error response: %d\n", res.status);
  } else {
    rc = 0;
  }
  return rc;
}

int 
flume_set_label (const x_label_t *in, label_type_t typ, int force)
{
  set_label_arg_t set_arg;
  CLEAR (set_arg);

  set_arg.which.type = typ;
  set_arg.which.specifiers.scope = LABEL_SCOPE_PROCESS;
  set_arg.force = force;
  if (in)
    set_arg.new_label = *in;
  return set_label_common (&set_arg);
}

int
flume_set_fd_label (const x_label_t *in, label_type_t typ, int fd)
{
  set_label_arg_t set_arg;
  CLEAR (set_arg);
  set_arg.which.type = typ;
  set_arg.which.specifiers.scope = LABEL_SCOPE_FD;
  set_arg.which.specifiers.u.fd = fd;
  set_arg.force = 0;
  if (in)
    set_arg.new_label = *in;
  return set_label_common (&set_arg);
}

int
flume_expand_label (label_type_t type, x_handle_t h)
{
  get_label_arg_t get_arg;
  get_label_res_t get_res;
  set_label_arg_t set_arg;
  flume_res_t set_res;
  int rc = -1;
  int rrc;
  unsigned i;

  CLEAR (get_arg);
  CLEAR (get_res);
  CLEAR (set_arg);
  CLEAR (set_res);

  get_arg.type = type;
  get_arg.specifiers.scope = LABEL_SCOPE_PROCESS;

  
  if (rpc_call (GET_LABEL, &get_arg, &get_res, "get_label") < 0) {
    /* noop */
  } else if (get_res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_expand_label: non-OK result: %d\n", get_res.status);
    FLUME_SET_ERRNO_UNION(get_res);
    goto done;
  }

  for (i=0; i<get_res.u.label.len; i++) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"  handle: %" PRIx64 "\n", get_res.u.label.val[i]);
    if (get_res.u.label.val[i] == h) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "flume_expand_label: err3\n");
      FLUME_SET_ERRNO (FLUME_ERR);
      goto done;
    }
  }
  
  set_arg.which.type = type;
  set_arg.which.specifiers.scope = LABEL_SCOPE_PROCESS;
  set_arg.new_label.len = get_res.u.label.len + 1;
  set_arg.new_label.val = malloc (sizeof(x_handle_t) * set_arg.new_label.len);
  memcpy (set_arg.new_label.val, get_res.u.label.val, 
          sizeof(x_handle_t) * get_res.u.label.len);
  set_arg.new_label.val[get_res.u.label.len] = h;

  rrc = rpc_call (SET_LABEL, &set_arg, &set_res, "set_label");

  free (set_arg.new_label.val);
  if (rrc < 0) {
    /* noop */
  } else if (set_res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_expand_label: err5 %d\n", set_res.status);
    FLUME_SET_ERRNO (set_res.status);
  } else {
    rc = 0;
  }

 done:
  xdr_free ((xdrproc_t) xdr_get_label_res_t, (char *) &get_res);
  return rc;
}

int
flume_shrink_label (label_type_t type, x_handle_t h)
{
  get_label_arg_t get_arg;
  get_label_res_t get_res;
  set_label_arg_t set_arg;
  flume_res_t set_res;
  int rc = -1;

  CLEAR (get_arg);
  CLEAR (get_res);
  CLEAR (set_arg);
  CLEAR (set_res);

  FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "trying to remove %" PRIx64 "\n", h);

  /* Get our current O label */
  get_arg.type = type;
  get_arg.specifiers.scope = LABEL_SCOPE_PROCESS;

  if (rpc_call (GET_LABEL, &get_arg, &get_res, "get_label") < 0) {
    goto done;
  } else if (get_res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "flume_shrink_label: err2\n");
    FLUME_SET_ERRNO_UNION (get_res);
    goto done;
  }

  /* Prepare args to set_label */
  set_arg.which.type = type;
  set_arg.which.specifiers.scope = LABEL_SCOPE_PROCESS;
  label_resize (&set_arg.new_label, get_res.u.label.len, 0);

  unsigned i, j = 0;
  for (i=0; i<get_res.u.label.len; i++) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"  handle: %" PRIx64 "\n", get_res.u.label.val[i]);
    if (handle_base(get_res.u.label.val[i]) == handle_base(h)) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "  removing handle\n");
      continue;
    } else {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "  saving handle\n");
      label_set (&set_arg.new_label, j++, get_res.u.label.val[i]);
    }
  }
  label_resize (&set_arg.new_label, j, 1);

  if (set_arg.new_label.len == get_res.u.label.len) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_shrink_label: could not find handle %" PRIx64 ", "
		"cannot shrink\n", h);
    FLUME_SET_ERRNO (FLUME_ENOENT);
    goto done;
  }

  /* Send the set_label rpc */
  rc = FLUME_OK;

  if (rpc_call (SET_LABEL, &set_arg, &set_res, "set_label") < 0) {
    /* noop */
  } else if (set_res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_shrink_label: err5 %d\n", set_res.status);
    FLUME_SET_ERRNO (set_res.status);
  } else {
    rc = 0;
  }

 done:
  xdr_free ((xdrproc_t) xdr_get_label_res_t, (char *) &get_res);
  label_clear (&set_arg.new_label);
  return rc;
}

int
flume_stat_file (x_labelset_t *out, const char *p)
{
  file_arg_t arg;
  file_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);

  arg.c_args.path = (char *)p;
  if (rpc_call (FLUME_FLUME_STAT_FILE, &arg, &res, "stat_file") < 0) {
    /* noop */
  } else if (res.status == FLUME_OK) {
    labelset_clear (out);
    rc = 0;
  } else if (res.status == FLUME_LABEL_OK) {
    rc = labelset_copy (out, &res.u.label);
  } else {
    FLUME_SET_ERRNO_UNION(res);
  }

  free_file_res(&res);
  return rc;
}


int
flume_stat_group (x_labelset_t *out, x_handle_t g)
{
  group_stat_arg_t arg;
  group_stat_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);

  arg.group = g;
  rc = FLUME_OK;

  if (rpc_call (FLUME_STAT_GROUP, &arg, &res, "stat_group") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_stat_group: Error: %d\n", res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    rc = labelset_copy (out, &res.u.ls);
  }

  xdr_free ((xdrproc_t) xdr_group_stat_res_t, (char *)&res);
  return rc;
}

int
flume_new_group (x_handle_t *out, const char *name, const x_labelset_t *ls)
{
  new_group_arg_t arg;
  new_group_res_t res;
  int rc = 0;

  CLEAR (arg);
  CLEAR (res);

  arg.name = (char *)name;
  if (ls)
    arg.labels = *ls;

  if (rpc_call (NEW_GROUP, &arg, &res, "new_group") < 0) {
    /* noop */
  } else  if (res.status != FLUME_OK) {
    rc = -1;
    FLUME_SET_ERRNO_UNION(res);
  } else {
    *out = res.u.group.base_h;
  }
  xdr_free ((xdrproc_t) xdr_new_group_res_t, (char *)&res);
  return rc;
}

int
flume_add_to_group (x_handle_t group, x_handlevec_t *newhandles)
{
  operate_on_group_arg_t arg;
  flume_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);
  
  arg.group = group;
  arg.op = GROUP_OPERATION_ADD;
  arg.terms = *newhandles;

  if (rpc_call (OPERATE_ON_GROUP, &arg, &res, "add_to_group") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_add_to_group: RM error %d\n", res.status);
    FLUME_SET_ERRNO_UNION (res);
  } else {
    rc = 0;
  }
  xdr_free ((xdrproc_t) xdr_flume_res_t, (char *)&res);
  return rc;
}

int
flume_new_handle (x_handle_t *out, int opts, const char *name)
{
  new_handle_arg_t arg;
  new_handle_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);

  arg.name = (char *) name;
  arg.prefix = opts;

  if (rpc_call (NEW_HANDLE, &arg, &res, "new_handle") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_new_handle: non-OK status: %d\n", res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    rc = 0;
    *out = res.u.base_h;
  }
  return rc;
}

int
flume_make_login (x_handle_t h, u_int dur, char fixed, char **out_token)
{
  /* Prefix must include HANDLE_OPT_PERSISTENT  */
  make_login_arg_t arg;
  make_login_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);

  if (!(handle_prefix(h) & HANDLE_OPT_PERSISTENT)) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_make_login: cannot make login for non-persistent "
		"handle\n");
    FLUME_SET_ERRNO(FLUME_EPERSISTENCE);
  } else {
    
    arg.handle = h;
    arg.duration = dur;
    arg.fixed = fixed;
    arg.desired_tok_typ = PRIV_TOK_STR;
    
    if (rpc_call (MAKE_LOGIN, &arg, &res, "make_login") < 0) {
      /* noop */
    } else if (res.status != FLUME_OK) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_make_login: error from RM %d\n", res.status);
      FLUME_SET_ERRNO_UNION (res);
    } else if (res.u.token.typ != PRIV_TOK_STR) {
      FLUME_SET_ERRNO (FLUME_EINVAL);
    } else {
      if (out_token)
	*out_token = strdup (res.u.token.u.strtok);
      rc = 0;
    }
  }

  xdr_free ((xdrproc_t) xdr_make_login_res_t, (char *) &res);
  return rc;
}

int
flume_subset_of (const x_label_t *l, const x_label_t *rv, int len,
		setcmp_type_t typ)
{
  subset_of_arg_t arg;
  int out = -1;

  CLEAR (arg);

  arg.lhs = *l;
  arg.rhs.val = (x_label_t *)rv;
  arg.rhs.len = len;
  arg.typ = typ;

  if (rpc_call (FLUME_SUBSET_OF, &arg, &out, "subset_of")  < 0) {
    /* noop */
    out = -1;
  }

  return out;
}

int
flume_unixsocket (const char *path, x_labelset_t *ls)
{
  file_arg_t arg;
  file_res_t res;
  int rc = -1;
  int fd;

  CLEAR (arg);
  CLEAR (res);

  arg.c_args.path = (char *) path;
  arg.c_args.mode = 0644;
  arg.c_args.flags = 0;
  arg.xls = ls;

  /* create the socket */
  if (rpc_call_fd (FLUME_UNIXSOCKET, &arg, &res, "unixsocket", &fd) < 0) {
    /* noop */
  } else if (res.status != FLUME_FDPASS_OK_OPAQUE) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_unixsocket: non-ok response from FLUME_UNIXSOCKET " 
		"RPC %d \n", res.status);
    FLUME_SET_ERRNO_UNION (res);
  } else {

    /* receive the socket's fd */
    if (fd < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_unixsocket: error receiving fd\n");
      FLUME_SET_ERRNO(FLUME_ERR);
    } else if (register_fd (fd, res.u.opaque_h) < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_unixsocket: error registering fd %d with RM \n", fd);
      FLUME_SET_ERRNO(FLUME_ERR);
    } else {
      set_fd_status (fd, FD_SOCKET);
      rc = fd;
    }
  }

  free_file_res (&res);
  return rc;
}

int
flume_listen (int fd, int queue_len)
{
  listen_arg_t arg;
  flume_status_t res;
  int rc = -1;
  
  arg.fd = fd;
  arg.queue_len = queue_len;

  if (rpc_call (FLUME_LISTEN, &arg, &res, "listen") < 0) {
    /* noop */
  } else if (res != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "flume_listen: error %d \n", res);
    FLUME_SET_ERRNO (res);
  } else {
    rc = 0;
  }
  return rc;
}

int
flume_accept (int fd)
{
  u_int64_t val;
  ssize_t sz = sizeof (val);

  int rc = read (fd, (void *) &val, sz);
  if (rc < 0) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                "flume_accept: error accepting connection on fd %d\n", fd);
    FLUME_SET_ERRNO(FLUME_ERR);
  } else if (rc == 0) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                "flume_accept: got EOF on accept, fd %d\n", fd);
    FLUME_SET_ERRNO (FLUME_ERR);
  } else if (rc != sz) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
                "flume_accept: expected %d bytes but got %d bytes\n", 
		(int) sz, rc);
    FLUME_SET_ERRNO (FLUME_ERR);
  } else {
    rc = flume_claim_socket (val, "accept(2)ed socket");
    if (rc < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
                  "flume_accept: error claiming fd\n");
    } else {
      set_fd_status (fd, FD_SOCKET);
    }
  }
  return rc;
}

/* Returns the FD on success and -1 on failure */
int
flume_unixsocket_connect_c (const char *path)
{
  int fd = -1;
  struct sockaddr_un sun;

  memset (&sun, 0, sizeof (sun));
  sun.sun_family = AF_UNIX;

  if (strlen (path) >= sizeof (sun.sun_path)) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                 "flume_unixsocket_connect: name too long\n");
    FLUME_SET_ERRNO(FLUME_ERR);
  } else if (!strcpy (sun.sun_path, path)) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                 "flume_unixsocket_connect: unexpected error\n");
    FLUME_SET_ERRNO(FLUME_ERR);

  } else if ((fd = flume_socket (AF_UNIX, SOCK_STREAM, 0)) < 0) {
    /* no op */
  } else if (flume_connect (fd, (struct sockaddr *) &sun, 
                            sizeof (sun)) < 0) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
                 "flume_unixsocket_connect: error connecting\n");
    close (fd);
    fd = -1;
  }
  return fd;
}

int
flume_mkdir_full (const char *fn, mode_t mode, x_labelset_t *ls)
{
  file_arg_t arg;
  file_res_t res;
  int rc = -1;

  CLEAR (arg);
  CLEAR (res);

  arg.c_args.path = (char *)fn;
  arg.c_args.mode = mode;
  arg.xls = ls;

  if (rpc_call (FLUME_MKDIR,  &arg, &res, "flume_mkdir_full") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"mkdir_full: non-OK response: %d\n", res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    rc = 0;
  }
  free_file_res (&res);
  return rc;
}

/* returns 0 on success, -1 on failure */
int flume_socketpair (int duplex_mode, int *myfd, x_handle_t *theirtoken,
		     const char *desc)
{
  int fd;
  pipe_res_t res;
  enum clnt_stat err;

  if (!(duplex_mode & DUPLEX_FULL)) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "invalid duplex mode\n");
    FLUME_SET_ERRNO (FLUME_EINVAL);
    return -1;
  }

  if (duplex_mode == (int) DUPLEX_FULL) {
    socketpair_arg_t sarg;
    CLEAR (sarg);
    sarg.domain = AF_UNIX;
    sarg.type = SOCK_STREAM;
    sarg.protocol = 0;
    if (!desc)
      desc = "generic socketpair";
    sarg.desc = (char *)desc;
    err = rpc_call_fd (FLUME_SOCKETPAIR, &sarg, &res, "flume_socketpair", &fd);
  } else {
    pipe_arg_t parg;
    CLEAR (parg);
    parg.writing = (duplex_mode & (int) DUPLEX_ME_TO_THEM);
    if (!desc)
      desc = "generic pipe";
    parg.desc = (char *)desc;
    err = rpc_call_fd (FLUME_PIPE, &parg, &res, "flume_socketpair", &fd);
  }

  if (err) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_socketpair: RPC error: %d\n", err);
    FLUME_SET_ERRNO (FLUME_ERPC);
    return -1;
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		"flume_socketpair: RM error: %d\n", res.status);
    FLUME_SET_ERRNO_UNION(res);
    return -1;
  } else {
    if (fd < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_socketpair: error receiving fd\n");
      FLUME_SET_ERRNO(FLUME_ERR);
      return -1;
    } else if (register_fd (fd, res.u.hpair.my_end) < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_socketpair: error registering "
		  "fd %d with RM\n", fd);
      FLUME_SET_ERRNO(FLUME_ERR);
      return -1;
    } else {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
                  "flume_socketpair: got socketpair, my "
				  	"fd %d, token %" PRIx64 "\n",
                  fd, res.u.hpair.their_end);
      
      assert (myfd);
      assert (theirtoken);
      *myfd = fd;
      set_fd_status (fd, FD_SOCKET);
      *theirtoken = res.u.hpair.their_end;

      return 0;
    }
  }
}

int
flume_freeze_label (frozen_label_t *out, const x_label_t *in)
{
  int rc = -1;
  freeze_label_res_t tc;
  if (rpc_call (FLUME_FREEZE_LABEL, (x_label_t *)in, &tc, 
                "freeze_label") < 0) {
    /* noop */
  } else if (tc.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"Non-OK status from RM in FREEZE_LABEL: %d\n", tc.status);
    FLUME_SET_ERRNO_UNION(tc);
  } else {
    *out = tc.u.frozen;
    rc = 0;
  }
  xdr_free ((xdrproc_t) xdr_freeze_label_res_t, (char *) &tc);
  return rc;
}

int
flume_thaw_label (x_label_t *out, const frozen_label_t *in)
{
  int rc = -1;
  thaw_label_res_t res;
  CLEAR (res);
  
  if (rpc_call (FLUME_THAW_LABEL, (frozen_label_t *)in, &res,
                "thaw_label") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"Non-OK status from RM in THAW_LABEL: %d\n", res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    label_copy (out, &res.u.thawed);
    rc = 0;
  }

  xdr_free ((xdrproc_t) xdr_thaw_label_res_t, (char *) &res);
  return rc;
}

int
flume_make_nickname (x_handle_t h, const char *name)
{
  int rc = -1;
  flume_status_t res;
  new_nickname_arg_t arg;
  arg.nickname = (char *)name;
  arg.handle = h;
  if (rpc_call (FLUME_NEW_NICKNAME, &arg, &res, "mknick") < 0) {
    /* noop */
  } else if (res != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"Non-OK status from RM in NEW_NICKNAME: %d\n", res);
    FLUME_SET_ERRNO (res);
  } else {
    rc = 0;
  }
  return rc;
}

int
flume_lookup_by_nickname (x_handle_t *h, const char *nm)
{
  int rc = -1;
  new_handle_res_t res;

  if (rpc_call (LOOKUP_HANDLE_BY_NICKNAME, (char *)nm, 
                &res, "lookup") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"Non-OK status from RM in LOOKUP: %d\n", res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    *h = res.u.base_h;
    rc = 0;
  }
  return rc;
}

/* returns the fd, or -1 on failure */
int flume_claim_socket (x_handle_t theirtoken, const char *desc)
{
  int rc = -1;
  claim_res_t res;
  int fd;

  claim_arg_t arg;
  CLEAR (arg);

  arg.token = theirtoken;
  if (!desc)
    desc = "generic claimed socket";
  arg.desc = (char *)desc;

  if (rpc_call_fd (FLUME_CLAIM_FD, &arg, &res, 
                   "flume_claim_socket", &fd) < 0) {
    FLUME_SET_ERRNO(FLUME_ERR);
  } else if (res.status != FLUME_OK) {
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, "flume_claim_socket: RM error: %d\n", 
		res.status);
    FLUME_SET_ERRNO_UNION(res);
  } else {
    if (fd < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_claim_socket: error receiving fd\n");
      FLUME_SET_ERRNO(FLUME_ERR);
    } else if (register_fd (fd, res.u.ok.opaque_h) < 0) {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr, 
		  "flume_claim_socket: error registering "
		  "fd %d with RM\n", fd);
    } else {
      FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
                  "flume_claim_socket: got socket, my fd %d for "
				  "token %" PRIx64 "\n",
                  fd, theirtoken);
      rc = fd;
      set_fd_status (fd, FD_SOCKET);
    }
  }
  return rc;
}

char *
flume_random_str (int n)
{
  char *res = NULL;
  
  if (rpc_call (GENERATE_RANDOM_STR, &n, &res, "random str") < 0) {
    /* noop */
  }
  return res;
}

char *
flume_labelset_to_filename (const x_labelset_t *ls)
{
  file_res_t res;
  char *ret = NULL;

  CLEAR (res);
  
  if (rpc_call (FLUME_LABELSET_TO_FILENAME, (void *)ls, 
                &res, "labelset2str") <0) {
    /* noop */
  } else if (res.status != FLUME_PATH_OK) {
    FLUME_SET_ERRNO_UNION (res);
  } else {
    ret = strdup (res.u.path);
  }

  free_file_res(&res);
  return ret;
}

int flume_filename_to_labelset (const char *filename, x_labelset_t *out)
{
  str2labelset_arg_t arg;
  str2labelset_res_t res;
  CLEAR (arg);
  CLEAR (res);
  int rc = -1;

  arg.s = (char *)filename;
  
  if (rpc_call (FLUME_FILENAME_TO_LABELSET, 
                &arg, &res, "filename_to_labelset") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_SET_ERRNO (res.status);
    FLUME_DEBUG (FLUME_DEBUG_CLNT, stderr,
		"flume_filename_to_labelset: Error response: %d\n", rc);
  } else {
    rc = labelset_copy (out, &res.u.labelset);
  }
  return rc;
}

int
flume_setuid_tag (x_handle_t *h)
{
  int rc = -1;
  get_setuid_h_res_t res;

  if (rpc_call (FLUME_GET_SETUID_H, NULL, &res, "get_setuid_h") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK) {
    FLUME_SET_ERRNO(res.status);
  } else {
    *h = res.u.h;
    rc = 0;
  }
  return rc;
}

/* claim_fds either null, or a null terminated array.  Return 0 if
 * spawn worked, -1 on error, or 1 if the process disappeared.
 */
int
flume_spawn (x_handle_t *flmpid, 
	     const char *cmd, 
	     char *const argv[], 
	     char *const env[], 
	     int options,
	     const x_handlevec_t *claim_fds,
	     const x_label_change_set_t *label_changes,
	     const x_label_t *I_min,
	     const x_endpoint_t *endpoint,
	     const x_endpoint_t *ch_endpoint)
{
  spawn_arg_t arg;
  spawn_res_t res;
  int rc = -1;

  CLEAR(arg);
  CLEAR(res);

  arg.c_args.cmd = (char *)cmd;

  argv2pathvec (argv, &arg.c_args.argv);
  argv2pathvec (env, &arg.c_args.env);
  arg.c_args.wd = "/";

  arg.opts = options;
  if (label_changes) {
    arg.label_changes = *label_changes;
  } else {
    arg.label_changes.len = 0;
    arg.label_changes.val = NULL;
  }
  arg.claim_fds = (x_handlevec_t *)claim_fds;
  arg.I_min = (x_label_t *)I_min;
  arg.endpoint = (x_endpoint_t *)endpoint;
  arg.ch_endpoint = (x_endpoint_t *)ch_endpoint;
  
  if (rpc_call (FLUME_SPAWN, &arg, &res, "spawn") < 0) {
    /* noop */
  } else if (res.status != FLUME_OK && res.status != FLUME_EDISAPPEARED) {
    FLUME_SET_ERRNO_UNION (res);
  } else {
    *flmpid = res.u.ok.flmpid;
    rc = (res.status == FLUME_OK ? SPAWN_OK : SPAWN_DISAPPEARED );
  }
  return rc;
}

int flume_spawn_legacy (x_handle_t *flmpid, 
			const char *cmd, 
			char *const argv[], 
			char *const env[], 
			int confined,
			int opts,
			const x_labelset_t *new_ls,
			const x_handlevec_t *claim_fds,
			const x_label_t *I_min)
{
  if (confined) opts &= SPAWN_CONFINED;
  x_label_change_set_t lcs;
  x_label_change_t *lc;
  x_label_t *l;
  
  int n = 0;

  label_change_set_init (&lcs);
  label_change_set_resize (&lcs, 3, 0);

#define Cp(L) \
  do {                                                       \
    if ((l = labelset_get_##L ((x_labelset_t *)new_ls))) {   \
      lc = label_change_set_getp (&lcs, n);                  \
      label_change_set_which (lc, LABEL_##L);                \
      label_change_set_label (lc, l);                        \
      n++;                                                   \
    }                                                        \
  } while (0) 

  Cp(S);
  Cp(I);
  Cp(O);

#undef Cp


  label_change_set_resize (&lcs, n, 1);

  int rc = flume_spawn (flmpid, cmd, argv, env, opts, 
			claim_fds, &lcs, I_min, NULL, NULL);
  label_change_set_free (&lcs);
  
  return rc;
}

int
flume_waitpid (x_handle_t *pidout, int *vis, int *code, x_handle_t flmpid, 
              int options) 
{
  return flume_waitpid_common (pidout, vis, code, flmpid, options);
}

int flume_writefile (const char *path, int flags, int mode,
		    const x_labelset_t *ls, const char *buf, size_t bsz)
{
  file_arg_t arg;
  file_res_t res;
  int rc;
  
  CLEAR (res);
  CLEAR (arg);
  arg.c_args.path = (char *)path;
  arg.c_args.flags = flags;
  arg.c_args.mode = mode;
  arg.c_args.data.val = (char *)buf;
  arg.c_args.data.len = bsz;
  arg.xls = (x_labelset_t *)ls;
  
  rc = rpc_call (FLUME_WRITEFILE, &arg, &res, "writefile");
  if (rc == 0) {
    if (res.status != FLUME_OK) {
      rc = -1;
      FLUME_SET_ERRNO_UNION (res);
    }
  }
  free_file_res (&res);
  return rc;
}

int 
flume_apply_filter (x_filter_t *out, const char *path, 
		   label_type_t which)
{
  apply_filter_arg_t arg;
  file_res_t res;
  int rc;

  CLEAR (arg);
  CLEAR (res);
  arg.path = (char *)path;
  arg.which = which;

  rc = rpc_call (FLUME_APPLY_FILTER, &arg, &res, "apply");
  if (rc == 0) {
    if (res.status != FLUME_FILTER_OK) {
      rc = -1;
      FLUME_SET_ERRNO_UNION (res);
    } else {
      rc = filter_copy (out, &res.u.filter.filter);
    }
  }
  free_file_res (&res);
  return rc;
}

int
flume_kill (x_handle_t pid, int sig)
{
  kill_arg_t ka;
  ka.flmpid = pid;
  ka.sig = sig;
  flume_status_t st = FLUME_OK;
  int rc = 0;

  rc = rpc_call (FLUME_KILL, &ka, &st, "kill");
  if (rc == 0) {
    if (st != FLUME_OK) {
      FLUME_SET_ERRNO(st);
      rc = -1;
    }
  }
  return rc;
}

int
flume_null ()
{
  int rc = rpc_call (FLUME_NULL, NULL, NULL, "flume_null");
  return rc ? -1 : 0;
}


int flume_debug_msg (const char *s)
{
  debug_arg_t arg;
  CLEAR (arg);
  int rc = -1;

  arg.s = (char *)s;
  
  if (rpc_call (FLUME_DEBUG_MSG, &arg, NULL, "debug_msg") < 0) {
    /* noop */
  } else {
    rc = 0;
  }
  return rc;
}

int
flume_closed_files ()
{
  closed_files_arg_t arg;
  flume_status_t st = FLUME_OK;
  int rc;

  CLEAR (arg);
  arg.ctlsock = flume_myctlsock ();

  rc = rpc_call (FLUME_CLOSED_FILES, &arg, &st, "flume_closed_files");
  if (rc == 0) {
    if (st != FLUME_OK) {
      FLUME_SET_ERRNO (st);
      rc = -1;
    }
  }
  return rc;
}

int flume_send_capabilities (int fd, const x_capability_op_set_t *caps)
{
  send_capabilities_arg_t arg;
  flume_status_t st = FLUME_OK;
  int rc;

  CLEAR (arg);
  arg.dest_fd = fd;
  arg.capabilities = *caps;

  rc = rpc_call (SEND_CAPABILITIES, &arg, &st, "send_capabilities");
  if (rc == 0 && st != FLUME_OK) {
    FLUME_SET_ERRNO (st);
    rc = -1;
  }
  return rc;
}

int flume_verify_capabilities (int fd, capability_flag_t ops_on_all,
			       const x_capability_op_set_t *in,
			       x_capability_op_set_t *out)
{
  verify_capabilities_arg_t arg;
  verify_capabilities_res_t res;
  int rc;

  CLEAR (arg);
  CLEAR (res);

  arg.fd = fd;
  arg.ops_on_all = ops_on_all;
  arg.caps = *in;

  rc = rpc_call (VERIFY_CAPABILITIES, &arg, &res, "verify_capabilities");

  if (rc == 0) {
    if (res.status != FLUME_OK) {
      FLUME_SET_ERRNO (res.status);
      rc = -1;
    } else {
      capability_op_set_copy (out, &res.u.results);
    }
  }
  
  xdr_free ((xdrproc_t) xdr_verify_capabilities_res_t, (char *)&res);

  return rc;
}


int
flume_finish_fork (int fd, pid_t pid, int confined)
{
  flume_finish_fork_arg_t arg;
  flume_status_t res;
  int rc ;

  CLEAR(arg);
  arg.ctlsock = fd;
  arg.unix_pid = pid;
  arg.confined = confined;

  rc = rpc_call (FLUME_FINISH_FORK, &arg, &res, "flume_finish_fork");
  if (rc == 0 && res != FLUME_OK) {
    FLUME_SET_ERRNO (res);
    rc = -1;
  }
  return rc;
}

int
flume_setepopt (int fd, int op, int val)
{
  flume_setepopt_arg_t arg;
  flume_status_t res;
  int rc = 0;

  CLEAR(arg);

  arg.fd = fd;
  arg.opt.typ = op;
  switch (op) {
  case FLUME_EP_OPT_STRICT:
    arg.opt.u.strict = val;
    break;
  case FLUME_EP_OPT_FIX:
    break;
  default:
    FLUME_SET_ERRNO (FLUME_UNHANDLED);
    rc = -1;
  }

  if (rc >= 0) {
    rc = rpc_call (FLUME_SETEPOPT, &arg, &res, "flume_setepopt");
    if (rc == 0 && res != FLUME_OK) {
      FLUME_SET_ERRNO (res);
      rc = -1;
    }
  }
  return rc;
}
