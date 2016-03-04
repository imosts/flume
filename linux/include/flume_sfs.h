/* $Id: sfs-internal.h 2507 2007-01-12 20:28:54Z max $ */

/*
 *
 * Copyright (C) 1999 David Mazieres (dm@uun.org)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
 * USA
 *
 */

#ifndef _FLUME_SFS_H_
#define _FLUME_SFS_H_ 1

# define xdrlong_t long
# define HAVE_CMSGHDR 1

#ifdef FLUME_EVENT_CODE
# error "Cannot include this from Flume event code"
#endif

#include <rpc/rpc.h>

ssize_t readfd (int fd, void *buf, size_t len, int *rfdp);
ssize_t writefd (int fd, const void *buf, size_t len, int wfd);
int recvfd ();

#ifndef __linux__
static inline u_int64_t
dev2int (dev_t dev)
{
  return dev;
}
#else /* __linux__ */
static inline u_int64_t
dev2int (dev_t dev)
{
  switch (0) case 0: case sizeof (dev) == sizeof (u_int64_t):;
  return *(u_int64_t *) &dev;
}

#define HAVE_XDR_INT64_T 1
#define HAVE_XDR_UINT64_T 1
#undef HAVE_XDR_U_INT64_T


#endif /* __linux__ */

/*
 * Stuff required by arpcgen output
 */

#define RPC_EXTERN extern
#define RPC_CONSTRUCT(a, b)
#define RPC_UNION_NAME(n) u

#undef longlong_t
#define longlong_t int64_t
#undef u_longlong_t
#define u_longlong_t u_int64_t

#ifndef HAVE_XDR_U_INT64_T
bool_t xdr_u_int64_t (XDR *xdrs, u_int64_t *qp);
#endif /* !HAVE_XDR_U_INT64_T */
#ifndef HAVE_XDR_LONGLONG_T
#define xdr_longlong_t xdr_int64_t
#define xdr_u_longlong_t xdr_u_int64_t
#ifndef HAVE_XDR_INT64_T
bool_t xdr_int64_t (XDR *xdrs, int64_t *qp);
#endif /* !HAVE_XDR_INT64_T */
#endif /* HAVE_XDR_LONGLONG_T */

#define RPCGEN_ACTION(x) 0
struct rpcgen_table_tc {
  char *(*proc)();
  xdrproc_t xdr_arg;
  unsigned len_arg;
  xdrproc_t xdr_res;
  unsigned len_res;
};

struct rpc_program_tc {
  u_int32_t progno;
  u_int32_t versno;
  const struct rpcgen_table_tc *tbl;
  size_t nproc;
};

struct flume_bigint {
  u_int len;
  char *val;
};
typedef struct flume_bigint flume_bigint;
bool_t xdr_flume_bigint (XDR *xdrs, flume_bigint *bp);


enum clnt_stat srpc_callraw_fd (int fd,
				u_int32_t prog, u_int32_t vers, u_int32_t proc,
				xdrproc_t inproc, void *in,
				xdrproc_t outproc, void *out, AUTH *auth,
				int *fdout);

enum clnt_stat srpc_call_fd (const struct rpc_program_tc *, int fd, 
			     u_int32_t proc,
			     void *in, void *out, int *outfd);

enum clnt_stat 
srpc_callraw (int fd,
	      u_int32_t prog, u_int32_t vers, u_int32_t proc,
	      xdrproc_t inproc, void *in,
	      xdrproc_t outproc, void *out, AUTH *auth);

enum clnt_stat 
srpc_call (const struct rpc_program_tc *, int fd, u_int32_t proc,
	   void *in, void *out);

#endif /* _FLUME_SFS_H_ */
