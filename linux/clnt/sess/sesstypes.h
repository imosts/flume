#ifndef _SESSTYPES_H_
#define _SESSTYPES_H_

/* C programs should include this header to get the type definitions,
 * rather than sess.h because sess.h needs C++
 */

#define SESS_MAX_SIZE 1024

#define SESS_MSG_NEWSESS_REQ  1
#define SESS_MSG_NEWSESS_RPL  2
#define SESS_MSG_SAVESESS_REQ 3
#define SESS_MSG_SAVESESS_RPL 4
#define SESS_MSG_GETSESS_REQ  5
#define SESS_MSG_GETSESS_RPL  6

typedef u_int64_t sess_id_t;

typedef struct sess_msg {
  unsigned char msg_type;
  int return_code;
  sess_id_t sess_id;
  char buf[SESS_MAX_SIZE]; /* gross, should change this to variable size! */
} sess_msg_t;

#endif /* _SESSTYPES_H_ */
