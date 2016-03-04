#ifndef GENERICHELPERS_H
#define GENERICHELPERS_H

/* Helper functions common to all launchers */

#include "async.h"
#include "tame.h"
#include "flume_prot.h"

#define UN_COOKIE  "FLUME_UN"
#define UID_COOKIE "FLUME_UID"
#define GID_COOKIE "FLUME_GID"
#define TPW_COOKIE "FLUME_TPW"

#define UMGR_ID_ENV "FLUME_UMGR_ID"
#define IHOME       "/ihome"

#define SUBMIT_CREATE  "Create"
#define SUBMIT_LOGIN   "Login"
#define SUBMIT_SUBMIT  "Submit"

#define ARG_SUBMIT     "submit"
#define ARG_ACTION     "action"
#define ARG_UN         "username"
#define ARG_PW         "password"

#define ACTION_LOGINCREATE "logincreate"


void send_msg (const char *args, ...);
void output_redirect (str msg, str url, unsigned int delay);
void send_create_form (str form);
void send_logincreate_form (str form);
void set_cookies (str un, str uid, str gid, str tpw);
void clear_cookies ();

str flume_umgr ();
str expect_env2str (str s);
void generic_login (str un, str pw, str path, int delay);

bool illegal_filename (str s);
bool illegal_username (str s);
void spawn_child (x_labelset_t *child_labs, str exec, str script, cbv cb, CLOSURE);

#endif
