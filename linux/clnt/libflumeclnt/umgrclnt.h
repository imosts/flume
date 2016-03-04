// -*-c++-*-
#ifndef UMGRCLNT_H
#define UMGRCLNT_H

#include "async.h"
#include "tame.h"
#include "flume_prot.h"

typedef struct principal {
  str name;
  x_handle_t etag, wtag, rtag, gtag, uetag, itag;
  ihash_entry<principal> _lnk;
  principal (str n) { name = n; }
} principal_t;

typedef ihash<str, principal_t, &principal_t::name, &principal_t::_lnk > principal_hash_t;

int umgr_newuser (str umgr, str un, str pw, 
                  str &uid);

int umgr_login (str umgr, str un, str pw, 
                str &uid, str &gid, str &tpw);

int umgr_newuser_login (str umgr, str un, str pw,
                        str &uid, str &gid, str &tpw);


str uname_to_homedir_link (str umgr, str uname);
str uname_to_homedir (str umgr, str uname);
str uid_to_homedir (str uid);
str uid_to_tags_filename (str uid);
str uid_to_groups_filename (str uid);
principal_t *read_user_tags (str un, str uid, principal_hash_t *h = NULL);
str name2uid (str umgr, str uname);

#endif
