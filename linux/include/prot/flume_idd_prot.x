/*
 * A .x protocol for talking to IDD
 */

%#include "flume_prot.h"

union idd_member_of_res_t switch (ynm_t ynm) {
case YNM_YES:
	void;
case YNM_MAYBE:
	x_handlevec_t subgroups;
case YNM_NO:
	void;
};

struct idd_member_of_arg_t {
	x_caph_t       capability;
	x_handle_t     group;
};

struct idd_make_login_arg_t {
	make_login_arg_t larg;
	priv_tok_t token;	
};

union idd_get_group_labels_res_t switch (flume_status_t status) {
case FLUME_OK:
	frozen_labelset_t labels;
default:
	void;
	
};

struct idd_new_group_arg_t {
	group_name_t name;
	frozen_labelset_t labels;
};

struct insert_gea_arg_t {
	unsigned hyper hash;
	flume_extattr_t extattr;
};

union lookup_gea_res_t switch (flume_status_t status) {
case FLUME_OK:
	flume_extattr_t extattr;
default:
	void;
};

struct insert_handle_arg_t {
	handle_name_t name;
	x_handle_t handle;
};

typedef unsigned hyper lookup_gea_arg_t;

program FLUME_IDD_PROG {
	version FLUME_IDD_VERS {

		void
		IDD_NULL (void) = 0;

		new_handle_res_t
		IDD_NEW_HANDLE(new_handle_arg_t) = 1;

		new_group_res_t
		IDD_NEW_GROUP(idd_new_group_arg_t) = 2;
		
		flume_status_t
		IDD_OPERATE_ON_GROUP(operate_on_group_arg_t) = 3;
		
		freeze_label_res_t
		IDD_FREEZE_LABEL(x_label_t) = 4;

		thaw_label_res_t 
		IDD_THAW_LABEL(frozen_label_t) = 5;

		req_privs_res_t
		IDD_REQ_PRIVS(req_privs_arg_t) = 6;

		flume_status_t
		IDD_MAKE_LOGIN(idd_make_login_arg_t) = 7;

		idd_member_of_res_t 
		IDD_MEMBER_OF(idd_member_of_arg_t) = 8;

		new_handle_res_t
		IDD_LOOKUP_HANDLE_BY_NICKNAME(nickname_t) = 9;

		idd_get_group_labels_res_t
		IDD_GET_GROUP_LABELS(x_handle_t) = 10;

		flume_status_t 
		IDD_NEW_NICKNAME(new_nickname_arg_t) = 11;

		void
		IDD_MEMBER_OF_CACHE_INVALIDATE(x_handle_t) = 12;

		flume_status_t
		IDD_INSERT_GEA (insert_gea_arg_t) = 13;
	
		lookup_gea_res_t 
		IDD_LOOKUP_GEA (lookup_gea_arg_t) = 14;

		flume_status_t
		IDD_INSERT_HANDLE (insert_handle_arg_t) = 15;

	} = 1;

} = 22224;

