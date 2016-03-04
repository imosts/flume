
#include "okcompat.h"

//
// libamt
//
u_int ok_amt_lasi = 20;              // load avg sampling interval in secs
u_int ok_ldavg_rpc_timeout = 10;     // load avg RPC timeout in secs
u_int ok_ldavg_ping_interval = 2;    // load avg ping interval in secs
u_int ok_lblnc_launch_timeout = 15;  // wait before timeout in secs
u_int ok_amt_report_q_freq = 0;      // disable reporting by default
u_int ok_amt_q_timeout = 60;         // timeout RPCs longer than 1 minute
u_int ok_amt_stat_freq = 60;         // statistics frequency

//
// helper processes constants
//
u_int hlpr_max_calls = 1000;               // max outstanding calls
u_int hlpr_max_retries = UINT_MAX;         // ... before giving up
u_int hlpr_retry_delay = 4;                // delay between retries.
u_int hlpr_max_qlen = 1000;                // maximum # to q

//
// FDFD default command line arg
//
const char *ok_fdfd_command_line_flag = "-s";
