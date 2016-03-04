
// -*-c++-*-

#include "rm.h"
#ifdef HAVE_DEV_SYSTRACE_H
# include <dev/systrace.h>
# define DO_SYSTRACE
#endif

namespace rm {

  void
  rm_t::systrace_read ()
  {

#ifdef DO_SYSTRACE

    struct str_message msg;
    
    if (read (_strfd, &msg, sizeof(msg)) != sizeof(msg)) {
      FLUMEDBG3 (PROCESS, ERROR, 
                "systrace got an incorrectly sized msg from /dev/systrace, ignoring\n");
      return;
    }
    
    //warn ("msg (seq %d, type %d) is for process pid %d\n", 
    //msg.msg_seqnr, msg.msg_type, msg.msg_pid);
    
    switch (msg.msg_type) {
      
    case SYSTR_MSG_ASK: {
      if (0)
        FLUMEDBG4 (PROCESS, CHATTER, "systrace got SYSTR_MSG_ASK from pid %d, syscall %d\n",
                  msg.msg_pid, msg.msg_data.msg_ask.code);
      
      // Figure out what we'll say and respond to the ASK query
      struct systrace_answer strans;
      int action = systr_policy_get_action (_strfd, &msg);
      
      memset(&strans, 0, sizeof(strans));
      strans.stra_pid = msg.msg_pid;
      strans.stra_seqnr = msg.msg_seqnr;
      strans.stra_policy = action;
      if (ioctl(_strfd, STRIOCANSWER, &strans) == -1)
	FLUMEDBG4 (PROCESS, FATAL_ERROR, "STRIOCANSWER ioctl error %d, client pid %d, syscall %d, action %d\n", 
                  errno, msg.msg_pid, msg.msg_data.msg_ask.code, action);
      break;
    }
    case SYSTR_MSG_RES: {
      FLUMEDBG3 (PROCESS, CHATTER, "systrace got SYSTR_MSG_RES\n");
      break;
    }
    case SYSTR_MSG_EMUL:
      FLUMEDBG3 (PROCESS, ERROR, "systrace got SYSTR_MSG_EMUL, not supported!\n");
      break;
      
    case SYSTR_MSG_UGID:
      FLUMEDBG3 (PROCESS, ERROR, "systrace got SYSTR_MSG_UGID, not supported!\n");
      break;
      
    case SYSTR_MSG_CHILD:
      {
        int newpid = msg.msg_data.msg_child.new_pid;
        // Sent when process forks or exits.  If exit, the new pid == -1.
        FLUMEDBG4 (PROCESS, ERROR, "systrace got SYSTR_MSG_CHILD pid %d, new_pid %d\n", 
                  msg.msg_pid, newpid);
        if (newpid >= 0) {
          int rc = systr_confine_process(_strfd, newpid, CONFINE_LOCKDOWN);
          assert (rc >= 0);
        }
      }
      break;
    case SYSTR_MSG_EXECVE:
      FLUMEDBG3 (PROCESS, ERROR, "systrace got SYSTR_MSG_EXECVE, not supported!\n");
      break;
      
    case SYSTR_MSG_POLICYFREE:
      // We will get this msg if we insert a new policy when the kernel
      // has no more policy slots.  The kernel will replace an existing
      // policy and use this msg to tell us which policy was evicted.
      FLUMEDBG3 (PROCESS, FATAL_ERROR, "systrace: too many policies, fix this!\n");
      break;
    }

#endif /* DO_SYSTRACE */

  }

  //-----------------------------------------------------------------------

  int
  rm_t::systrace_open()
  {
    int cfd = -1;

#ifdef DO_SYSTRACE
    int fd;
    const char *path = _systrace_file.cstr ();

    fd = open (path, O_RDONLY, 0);
    if (fd == -1) {
      warn ("open: %s\n", path);
      return -1;
    }
    
    if (ioctl (fd, STRIOCCLONE, &cfd) == -1) {
      warn ("ioctl(STRIOCCLONE)\n");
      close(fd);
      return -1;
    }

    if (fcntl (cfd, F_SETFD, 1) == -1)
      warn("fcntl(F_SETFD)");
    
    if (fcntl(cfd, F_SETFL, O_NONBLOCK) == -1)
      warn("fcntl(O_NONBLOCK)");
    
#endif // DO_SYSTRACE

    return (cfd);
  }

  //-----------------------------------------------------------------------

}
