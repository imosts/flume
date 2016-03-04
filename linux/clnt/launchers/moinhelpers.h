#ifndef MOINHELPERS_H
#define MOINHELPERS_H

#include <time.h>
#include "async.h"
#include "tame.h"
#include "tame_io.h"
#include "flume_cpp.h"
#include "flume_ev_debug_int.h"
#include "ihash.h"
#include "flume_prot.h"
#include "umgrclnt.h"
extern "C" { 
#include "flume_api.h"
#include "flume_clnt.h"
}

#ifdef __linux__
#  define PYTHON                "/usr/bin/python"
#else
#  define PYTHON                "/usr/local/bin/python"
#endif
#define MOIN_STR              "moin"
#define CLASSIC_STR           "classic"
#define RIGHTSIDEBAR_STR      "rightsidebar"
#define MOIN_INSTANCE         "/disk/yipal/moin-instance"
#define PAGEDIR               "/ihome"
#define MOIN_USERS            "/ihome"
#define MOIN_I_ENV            "MOIN_I_TAG_LONG"
#define MOIN_I_PW_ENV         "MOIN_I_TAG_PW"
#define CLASSIC_I_ENV         "CLASSIC_I_TAG_LONG"
#define CLASSIC_I_PW_ENV      "CLASSIC_I_TAG_PW"
#define RIGHTSIDEBAR_I_ENV    "RIGHTSIDEBAR_I_TAG_LONG"
#define RIGHTSIDEBAR_I_PW_ENV "RIGHTSIDEBAR_I_TAG_PW"
#define UMGR_MOIN_FILTER_ENV         "UMGR_MOIN_FILTER"
#define MOIN_CLASSIC_FILTER_ENV      "MOIN_CLASSIC_FILTER"
#define MOIN_RIGHTSIDEBAR_FILTER_ENV "MOIN_RIGHTSIDEBAR_FILTER"

/* get stuff from ENV and filenames */
x_handle_t env_to_i_handle (const char *env, int opt);
int add_env_itag_to_i (const char *env);
int add_env_itag_to_o (const char *env, const char *env_pw);

//str moin_instance_dir (int use_ls);
str moin_cgi (bool frozen);

/* deal with user and tag files */
principal_t *read_tags (str un, str uid);
principal_t *me ();
principal_t *get_principal (str name);
void add_uetag (vec<x_handle_t> &v, principal_t *p);
void add_etag (vec<x_handle_t> *v, principal_t *p);
void add_all_etags (vec<x_handle_t> &v);

/* deal with moin URLs and their tags */
int add_moinpath_tags (label_type_t type, str path, vec<x_handle_t> &v);
x_label_t *moinpath_to_label (label_type_t type, str path);
str moinpath_to_dname (str path);
int check_link_labels (str path);

#endif /* MOINHELPERS_H */

