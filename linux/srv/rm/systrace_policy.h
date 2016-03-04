#ifndef _SYSTRACE_POLICY_H_
#define _SYSTRACE_POLICY_H_

#include "async.h"
#include "rm.h"
#include <sys/types.h>

#ifdef HAVE_DEV_SYSTRACE_H
# include <dev/systrace.h>
#endif

namespace rm {

  int systr_confine_process (int strfd, pid_t pid, confinement_level_t lev);
  int systr_policy_get_action (int strfd, struct str_message *msg);

}
#endif /* _SYSTRACE_POLICY_H_ */
