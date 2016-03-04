
// -*-c++-*-
/* $Id: okconst.h 2069 2006-06-29 20:45:22Z max $ */

#ifndef _LIBAMYSQL_OKCOMPAT_H_
#define _LIBAMYSQL_OKCOMPAT_H_ 1

#include "async.h"
#include "arpc.h"

TYPE2STRUCT(, long long);
TYPE2STRUCT(, short);
TYPE2STRUCT(, unsigned short);
TYPE2STRUCT(, unsigned long long);

#define sNULL (str )NULL

#define LOAD_AVG_MAX      UINT_MAX
#define LOAD_AVG_RPC      100
#define Q_LEN_RPC         101

//
// Async-Multi-Threaded stuff
//
extern u_int ok_amt_lasi;                       // load avg sampling interval
extern u_int ok_ldavg_rpc_timeout;              // load avg RPC timeout
extern u_int ok_ldavg_ping_interval;            // how often to qry for loadavg
extern u_int ok_lblnc_launch_timeout;           // launch timeout
extern u_int ok_amt_report_q_freq;              // report q frequency
extern u_int ok_amt_q_timeout;                  // timeout RPCs sitting in Q
extern u_int ok_amt_stat_freq;                  // statistics sampling freq

//
// helper constants
//
extern u_int hlpr_max_calls;                   // max outstanding calls
extern u_int hlpr_max_retries;                 // ... before giving up
extern u_int hlpr_retry_delay;                 // delay between retries.
extern u_int hlpr_max_qlen;                    // maximum # to q

//
// command line flag to use (by default) when passing an FDFD to
// a child. An FDFD is an FD used for sending other FDs over.
//
extern const char *ok_fdfd_command_line_flag;

#endif /* _LIBAMYSQL_OKCOMPAT_H_ */
