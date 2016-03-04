

/*
 * Flume constants as preproc macros, for maximum protability across C/C++.
 */

#ifndef _FLUME_CONST_H_
#define _FLUME_CONST_H_


#define FLUME_DEBUG_INTERCEPT 0x1
#define FLUME_DEBUG_MEMORY    0x2
#define FLUME_DEBUG_LIBC      0x4
#define FLUME_DEBUG_CONNECT   0x8
#define FLUME_DEBUG_FEXEC     0x10
#define FLUME_DEBUG_CLNT      0x20
#define FLUME_DEBUG_SESS      0x40
#define FLUME_DEBUG_EMPTY1    0x80
#define FLUME_DEBUG_LINKER    0x100
#define FLUME_DEBUG_CLNT_ANY  0xfff

#define FLUME_DEBUG_JAIL                       0x1000
#define FLUME_DEBUG_FD_PASSING                 0x2000
#define FLUME_DEBUG_HLP_STATUS                 0x4000
#define FLUME_DEBUG_SOCKETS                    0x8000
#define FLUME_DEBUG_FS                         0x10000
#define FLUME_DEBUG_PROCESS                    0x20000
#define FLUME_DEBUG_RPC                        0x40000
#define FLUME_DEBUG_PROXY                      0x80000
#define FLUME_DEBUG_LABELOPS                   0x100000
#define FLUME_DEBUG_FDS                        0x200000
#define FLUME_DEBUG_SPAWN                      0x400000
#define FLUME_DEBUG_PROFILE                    0x800000
#define FLUME_DEBUG_CACHE                      0x1000000

#define FLUME_DEBUG_SRV_ANY                    0xfffff000

// The 3 variables a process might set in order to influence the 
// dynamic linker.  All others (rings, etc) have been phased out
#define FLUME_DBG_EV "FLUME_DEBUG_LEVEL"
#define FLUME_DBG_SRV_EV "FLUME_DEBUG_SRV"
#define FLUME_SCK_EV "FLUME_SOCKET"
#define FLUME_SFD_EV "FLUME_SOCKET_FD"

#define FLUME_UNDEF_EV "FLUME_UNDEF"
#define FLUME_PRCID_EV "FLUME_PROC_ID"
#define FLUME_CLCK_EV "FLUME_CLOCK"
#define FLUME_CONFINED_EV "FLUME_CONFINED"
#define FLUME_YES "YES"
#define FLUME_NO "NO"
#define FLUME_INTERPOSING_INITIAL_EV "FLUME_INTERPOSING_INITIAL"

typedef enum {
	FLUME_CONFINE_NONE = 0,
	FLUME_CONFINE_VOLUNTARY = 1,
	FLUME_CONFINE_ENFORCED = 2
} flume_confinement_t ;

//
// Pass these args to prctl to talk to flume_lsm
//
#define FLUME_PRCTL_ENABLE       0x77
#define FLUME_PRCTL_PUTFD        0x78
#define FLUME_PRCTL_CLOSED_FILES 0x79
#define FLUME_PRCTL_CONFINE_ME   0x80


// A fake PID to use instead of real one, if no pid is available...
#define FLUME_FAKE_PID (pid_t )0x7ffffffe

#endif /* _FLUME_CONST_H_ */
