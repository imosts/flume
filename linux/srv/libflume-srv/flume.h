
// -*-c++-*-
/* $Id: flumedbg-int.h 1682 2006-04-26 19:17:22Z max $ */

/*
 */

#ifndef _LIBFLUME_FLUME_H_
#define _LIBFLUME_FLUME_H_ 1


#include "async.h"
#include "flume_ev.h"
#include "flume_ev_debug.h"
#include "flume_ev_labels.h"

typedef callback<void, flume_status_t, int>::ref open_cb_t;
typedef callback<void, flume_status_t>::ref unlink_cb_t;

#endif /* _LIBFLUME_FLUME_H_ */
