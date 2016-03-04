// -*-c++-*-

#include "systrace_policy.h"
#include "async.h"
#include "rm.h"
#include <termios.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <sys/syscall.h>

#ifdef HAVE_DEV_SYSTRACE_H
# include <dev/systrace.h>
# define DO_SYSTRACE
#endif /* HAVE_DEV_SYSTRACE_H */

#define SYSPREFIX(x) SYS_##x

namespace rm {

#ifdef DO_SYSTRACE

  struct systrace_policy normal_policy;
  struct systrace_policy lockdown_policy;
  static bool initialized_policies = false;

  static int lockdown_permitted_syscalls[] = {
    SYSPREFIX(exit),
    SYSPREFIX(read),
    SYSPREFIX(write),
    SYSPREFIX(close),
    SYSPREFIX(recvmsg),
    SYSPREFIX(sendmsg),
    SYSPREFIX(recvfrom),
    SYSPREFIX(getpid),
    SYSPREFIX(sigprocmask),
    SYSPREFIX(poll),
    SYSPREFIX(getrlimit), // used by getdtablesize()
    SYSPREFIX(setrlimit), // used by libasync fdlim.h
    SYSPREFIX(getsockname),
    SYSPREFIX(select),
    SYSPREFIX(getsockopt),
    SYSPREFIX(setsockopt),
    SYSPREFIX(writev),
    SYSPREFIX(readv),
    SYSPREFIX(clock_gettime),
    SYSPREFIX(dup2),
    0
  };

  // Anyone can call these
  static int normal_permitted_syscalls[] = { 
    SYSPREFIX(exit),
    SYSPREFIX(read),
    SYSPREFIX(write),
    SYSPREFIX(close),
    SYSPREFIX(setuid),
    SYSPREFIX(getuid),
    SYSPREFIX(geteuid),
    SYSPREFIX(recvmsg),
    SYSPREFIX(sendmsg),
    SYSPREFIX(recvfrom),
    SYSPREFIX(getpeername),
    SYSPREFIX(getsockname),
    SYSPREFIX(getegid),
    SYSPREFIX(sigaction),
    SYSPREFIX(getgid),
    SYSPREFIX(sigprocmask),
    SYSPREFIX(mprotect),
    SYSPREFIX(poll),
    SYSPREFIX(issetugid),
    SYSPREFIX(clock_gettime),
    SYSPREFIX(writev),
    SYSPREFIX(readv),
    SYSPREFIX(getdirentries),
    SYSPREFIX(lseek),
    SYSPREFIX(select),
    SYSPREFIX(gettimeofday),
    SYSPREFIX(getrlimit), // used by getdtablesize()
    SYSPREFIX(setrlimit), // used by libasync fdlim.h
    286, // mquery
    292, // fstat
    SYSPREFIX(getsockopt),
    SYSPREFIX(setsockopt),
    SYSPREFIX(pipe),
    SYSPREFIX(fsync),
    SYSPREFIX(umask),
    SYSPREFIX(setitimer),
    SYSPREFIX(nanosleep),
    SYSPREFIX(getpid),
    NFEXEC,

    /* Sysctl is ok as long as they dont get root.  
     * If they get root, they can break out of jail anyway.
     *  (CTL_KERN, KERN_CLOCKRATE)
     *  (CTL_KERN, KERN_ARND)
     *  (CTL_HW, HW_PAGESIZE)
     *  (CTL_MACHDEP, CPU_OSFXSR)
     */
    SYSPREFIX(__sysctl),
    0,
  };

  // We do extra checks on these calls
  static int normal_monitored_syscalls[] = {
    SYSPREFIX(open),    // Interpose so we can get helpful debug msgs at the RM console

    SYSPREFIX(mmap),    // 197 : only allow read/exe, not write
    SYSPREFIX(munmap),  // 73
    SYSPREFIX(mprotect),// 74

    SYSPREFIX(fcntl),   // 92 : We do not allow F_GETLK, F_SETLK, F_SETLKW, F_GETOWN, F_SETOWN
    SYSPREFIX(ioctl),   // Python uses for TIOCGETA
    0,
  };

  static int modify_policy (int strfd, int policy_num, int syscallid, 
                            short newpolicy) 
  {
    struct systrace_policy strpol;

    strpol.strp_num = policy_num;
    strpol.strp_op = SYSTR_POLICY_MODIFY;
    strpol.strp_code = syscallid;
    strpol.strp_policy = newpolicy;
      
    if (ioctl(strfd, STRIOCPOLICY, &strpol) == -1) {
      warn("STRIOCPOLICY ioctl error");
      return -1;
    }
    return 0;
  }

  static int setup_policies (int strfd)
  {
    int i;
    int max_syscalls = MAX(SYS_MAXSYSCALL, NFEXEC);

    // allocate a policy in kernel for the normal policy
    normal_policy.strp_op = SYSTR_POLICY_NEW;
    normal_policy.strp_maxents = max_syscalls;
    if (ioctl(strfd, STRIOCPOLICY, &normal_policy) == -1) {
      warn ("SYSTR_POLICY_NEW ioctl error\n");
      return -1;
    }
    FLUMEDBG4 (PROCESS, CHATTER, "normal_policy %d\n", normal_policy.strp_num);

    // prohibit all syscalls to start off
    for (i = 0; i < max_syscalls; i++)
      if (modify_policy (strfd, normal_policy.strp_num, i, SYSTR_POLICY_ASK) < 0)
        return -1;
    // setup permitted syscalls
    for (i=0; normal_permitted_syscalls[i]; i++) 
      if (modify_policy (strfd, normal_policy.strp_num, 
                         normal_permitted_syscalls[i], SYSTR_POLICY_PERMIT) < 0)
        return -1;
    for (i=0; normal_monitored_syscalls[i]; i++) 
      if (modify_policy (strfd, normal_policy.strp_num, 
                         normal_monitored_syscalls[i], SYSTR_POLICY_ASK) < 0)
        return -1;

    // allocate a policy in kernel for the lockdown policy
    lockdown_policy.strp_op = SYSTR_POLICY_NEW;
    lockdown_policy.strp_maxents = max_syscalls;
    if (ioctl(strfd, STRIOCPOLICY, &lockdown_policy) == -1) {
      warn ("SYSTR_POLICY_NEW ioctl error\n");
      return -1;
    }
    FLUMEDBG4 (PROCESS, CHATTER, "lockdown_policy %d\n", lockdown_policy.strp_num);
    
    // prohibit all syscalls to start off
    for (i = 0; i < max_syscalls; i++)
      if (modify_policy (strfd, lockdown_policy.strp_num, i, SYSTR_POLICY_ASK) < 0)
        return -1;
    // setup permitted syscalls
    for (i=0; lockdown_permitted_syscalls[i]; i++) 
      if (modify_policy (strfd, lockdown_policy.strp_num, 
                         lockdown_permitted_syscalls[i], SYSTR_POLICY_PERMIT) < 0)
        return -1;
    
    initialized_policies = true;
    return 0;
  }

#endif // DO_SYSTRACE

  int systr_confine_process (int strfd, pid_t pid, confinement_level_t lev)
  {
#ifdef HAVE_DEV_SYSTRACE_H

    if (!initialized_policies && setup_policies (strfd) < 0)
      return -1;
    
    struct systrace_policy strpol;
    switch (lev) {
    case CONFINE_NORMAL:
      strpol = normal_policy;
      break;
    case CONFINE_LOCKDOWN:
      strpol = lockdown_policy;
      break;
    default:
      fatal ("incorrect confinement_level\n");
    }

    FLUMEDBG4 (PROCESS, CHATTER, "setting pid %d to confinement policy %d\n", 
              pid, strpol.strp_num);
    strpol.strp_op = SYSTR_POLICY_ASSIGN;
    strpol.strp_pid = pid;
    if (ioctl(strfd, STRIOCPOLICY, &strpol) == -1) {
      warn ("SYSTR_POLICY_ASSIGN ioctl error\n");
      return -1;
    }
    return 0;

#else /* HAVE_DEV_SYSTRACE_H */
    return -1;
#endif /* HAVE_DEV_SYSTRACE_H */

  }

#ifdef DO_SYSTRACE

  static void print_systr_arg (int strfd, struct str_message *msg, int argnum)
  {
    void *p;
    char c;
    struct systrace_io strio;

    memcpy(&p, &msg->msg_data.msg_ask.args[argnum], sizeof(p));
    do {
      memset(&strio, 0, sizeof(strio));
      strio.strio_pid = msg->msg_pid;
      strio.strio_op = SYSTR_READ;
      strio.strio_offs = p;
      strio.strio_addr = &c;
      strio.strio_len = 1;
    
      if (ioctl(strfd, STRIOCIO, &strio) == -1)
        warn ("STRIOCIO");
      if (c)
        fprintf (stderr, "%c", c);
      (unsigned char *)p += sizeof(char);
    } while (c != '\0');
  }

  static int open_action (int strfd, struct str_message *msg) 
  {
    // We can't actually use this code because we have to replace
    // open with flume_open.  This is here for illustration.
    fprintf (stderr, "flumerm: ** ERROR! systrace saw pid %d real open(", 
             msg->msg_pid);
    print_systr_arg (strfd, msg, 0);
    fprintf (stderr, ") something is wrong! **\n");
    return SYSTR_POLICY_NEVER;
  }

  static int fork_action (int strfd, struct str_message *msg)
  {
    FLUMEDBG4 (PROCESS, CHATTER, "systrace saw fork msg from pid %d, permitting\n", 
              msg->msg_pid);
    return SYSTR_POLICY_PERMIT;
  }

  static int fcntl_action (int strfd, struct str_message *msg)
  {
    if (msg->msg_data.msg_ask.argsize < 2) {
      fprintf (stderr, "systraced fcntl: not enough args\n");
      return SYSTR_POLICY_NEVER;
    }

    int cmd;
    memcpy (&cmd, &msg->msg_data.msg_ask.args[1], sizeof(cmd));
    switch (cmd) {
    case F_GETLK: 
      fprintf (stderr, "systrac rejecting fcntl F_GETLK\n");
      return SYSTR_POLICY_NEVER;
    case F_SETLK:
      fprintf (stderr, "systrac rejecting fcntl F_SETLK\n");
      return SYSTR_POLICY_NEVER;
    case F_SETLKW:
      fprintf (stderr, "systrac rejecting fcntl F_SETLKW\n");
      return SYSTR_POLICY_NEVER;
    case F_GETOWN:
      fprintf (stderr, "systrac rejecting fcntl F_GETOWN\n");
      return SYSTR_POLICY_NEVER;
    case F_SETOWN:
      fprintf (stderr, "systrac rejecting fcntl F_SETOWN\n");
      return SYSTR_POLICY_NEVER;
    }
    
    //FLUMEDBG4 (PROCESS, CHATTER, "systraced fcntl: allowing request type %d\n", cmd);
    return SYSTR_POLICY_PERMIT;
  }

  static int mmap_action (int strfd, struct str_message *msg)
  {
    if (msg->msg_data.msg_ask.argsize < 3) {
      fprintf (stderr, "systraced mmap: not enough args\n");
      return SYSTR_POLICY_NEVER;
    }

    int prot;
    memcpy (&prot, &msg->msg_data.msg_ask.args[2], sizeof(prot));
    if (prot == PROT_WRITE) {
      fprintf (stderr, "systraced mmap: rejecting PROT_WRITE!!\n");
      return SYSTR_POLICY_NEVER;
    }

    return SYSTR_POLICY_PERMIT;
  }

  static int munmap_action (int strfd, struct str_message *msg)
  {
    //fprintf (stderr, "flumerm: ** got munmap, permitting **\n");
    return SYSTR_POLICY_PERMIT;
  }

  static int mprotect_action (int strfd, struct str_message *msg)
  {
    //fprintf (stderr, "flumerm: ** got mprotect, permitting **\n");
    return SYSTR_POLICY_PERMIT;
  }

  static int execve_action (int strfd, struct str_message *msg)
  {
    fprintf (stderr, "flumerm: ** (pid %d) systrace saw exec (", msg->msg_pid);
    print_systr_arg (strfd, msg, 0);
    fprintf (stderr, ") msg, disallowing\n");
    return SYSTR_POLICY_PERMIT; // We should be disabling exec, and using fexec.
  }
  static int ioctl_action (int strfd, struct str_message *msg)
  {
    if (msg->msg_data.msg_ask.argsize < 2) {
      FLUMEDBG3 (PROCESS, CHATTER, "systraced ioctl: not enough args\n");
      return SYSTR_POLICY_NEVER;
    }

    unsigned long request;
    memcpy (&request, &msg->msg_data.msg_ask.args[1], sizeof(request));

    if (request != TIOCGETA) {
      FLUMEDBG4 (PROCESS, CHATTER, "systraced ioctl: rejecting request type %lx\n", request);
      return SYSTR_POLICY_NEVER;
    }
    
    FLUMEDBG4 (PROCESS, CHATTER, "systraced ioctl: allowing request type %lxx\n", request);
    return SYSTR_POLICY_PERMIT;
  }

#endif // DO_SYSTRACE

  int systr_policy_get_action (int strfd, struct str_message *msg)
  {

#ifdef HAVE_DEV_SYSTRACE_H

    int action = 0;
    int code = msg->msg_data.msg_ask.code;
    
    // Decide if we should permit this syscall
    switch (code) {
    case SYS_open:
      action = open_action(strfd, msg);
      break;
    case SYS_fork:
      action = fork_action(strfd, msg);
      break;
    case SYS_fcntl:
      action = fcntl_action(strfd, msg);
      break;
    case SYS_mmap:
      action = mmap_action(strfd, msg);
      break;
    case SYS_munmap:
      action = munmap_action(strfd, msg);
      break;
    case SYS_mprotect:
      action = mprotect_action(strfd, msg);
      break;
    case SYS_execve:
      action = execve_action(strfd, msg);
      break;
    case SYS_ioctl:
      action = ioctl_action(strfd, msg);
      break;

    default:
      {
        int i;
        bool found = false;
        //warn ("no handler for (pid %d) syscall %d\n", msg->msg_pid, code);

        for (i=0; normal_permitted_syscalls[i]; i++)
          if (code == normal_permitted_syscalls[i])
            found = true;
        for (i=0; normal_monitored_syscalls[i]; i++)
          if (code == normal_monitored_syscalls[i])
            found = true;
        
        if (!found) {
          fprintf (stderr, "systrace normal_mode prohibits syscall %d (pid %d), "
                   "permitting it for debugging\n", code, msg->msg_pid);
          if (0) sleep(60);
        }

        found = false;
        for (i=0; lockdown_permitted_syscalls[i]; i++)
          if (code == lockdown_permitted_syscalls[i])
            found = true;
        
        if (!found) {
          fprintf (stderr, "systrace lockdown_mode prohibits syscall %d (pid %d), "
                   "permitting it for debugging\n", code, msg->msg_pid);
          if (0) sleep (60);
        }
          
        //action = SYSTR_POLICY_NEVER;
        action = SYSTR_POLICY_PERMIT; // for testing purposes
      }
    }
    return action;

#else /* HAVE_DEV_SYSTRACE_H */
    panic ("no systrace!\n");
    return -1;
#endif /* HAVE_DEV_SYSTRACE_H */

  }
}
  
  
  
  
