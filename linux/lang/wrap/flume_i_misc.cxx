

extern "C" {
#include <fcntl.h>
#include "flume_features.h"
#include "flume_debug.h"
#include "flume_const.h"
#include "flume_prot.h"
#include "flume_api.h"
#include "flume_clnt.h"
}

#include "flume_i_ops.h"

ALLOC_SET_OBJ_OPS(x_label_change_set_t, label_change_set,
		  x_label_change_t, label_change);
ALLOC_SET_OBJ_OPS(x_capability_op_set_t, capability_op_set,
		  x_capability_op_t, capability_op);

ALLOC_SET_OBJ_OPS(x_endpoint_set_t, endpoint_set, x_endpoint_t, endpoint);

ALLOC_SET_OBJ_OPS(x_label_t, label, x_handle_t, handle);

ALLOC_SET_OBJ_OPS(x_int_set_t, int_set, int, int);
