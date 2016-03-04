
%#include "flume_prot.h"

/*
 * Protocol between the RM and the SPAWNER; trusted communication
 * only.
 */

struct spawn_i_res_ok_t {
	pid_t pid;
};

union spawn_i_res_t switch (flume_status_t status) {
case FLUME_OK:
	spawn_i_res_ok_t ok;
case FLUME_EPERM:
	perm_error_t eperm;
case FLUME_ERPC:
	int rpcerr;
default:
	void;
};

/*
 * Also accompanied with a FD that the new proc should use as a control
 * socket.
 */
struct spawn_i_arg_t {

	/* those taken from the original spawn_arg_t */
	spawn_c_arg_t c_args;
	spawn_opt_t opts;
	x_label_change_set_t label_changes;
        x_handlevec_t *claim_fds;
	x_label_t *I_min;

	/* additional arguments */
	x_handle_t flmpid;
	x_handle_t setuid_h;
};

struct spawn_i_exit_t {
	x_handle_t flmpid;
	pid_t pid;
	int status;
};

program FLUME_SPAWN_PROG {

	version FLUME_SPAWN_VERSION {

		void
		FLUME_SPAWN_NULL(void) = 0;

		spawn_i_res_t
		FLUME_SPAWN_SPAWN(spawn_i_arg_t) = 1;

		flume_status_t
		FLUME_SPAWN_EXIT (spawn_i_exit_t) = 2;

	} = 1;

} = 22224;
