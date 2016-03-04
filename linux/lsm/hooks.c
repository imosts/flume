

// take the following includes from security/selinux/hooks.c

#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/ptrace.h>
#include <linux/errno.h>
#include <linux/sched.h>
#include <linux/security.h>
#include <linux/xattr.h>
#include <linux/capability.h>
#include <linux/unistd.h>
#include <linux/mm.h>
#include <linux/mman.h>
#include <linux/slab.h>
#include <linux/pagemap.h>
#include <linux/swap.h>
#include <linux/smp_lock.h>
#include <linux/spinlock.h>
#include <linux/syscalls.h>
#include <linux/file.h>
#include <linux/namei.h>
#include <linux/mount.h>
#include <linux/ext2_fs.h>
#include <linux/proc_fs.h>
#include <linux/kd.h>
#include <linux/netfilter_ipv4.h>
#include <linux/netfilter_ipv6.h>
#include <linux/tty.h>
#include <net/icmp.h>
#include <net/ip.h>     /* for sysctl_local_port_range[] */
#include <net/tcp.h>        /* struct or_callable used in sock_rcv_skb */
#include <asm/uaccess.h>
#include <asm/ioctls.h>
#include <linux/bitops.h>
#include <linux/interrupt.h>
#include <linux/netdevice.h>    /* for network interface checks */
#include <linux/netlink.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/dccp.h>
#include <linux/quota.h>
#include <linux/un.h>       /* for Unix socket types */
#include <net/af_unix.h>    /* for Unix socket types */
#include <linux/parser.h>
#include <linux/nfs_mount.h>
#include <net/ipv6.h>
#include <linux/hugetlb.h>
#include <linux/personality.h>
#include <linux/sysctl.h>
#include <linux/audit.h>
#include <linux/string.h>
#include <linux/selinux.h>
#include <linux/mutex.h>
#include <linux/pid.h>

// Include flume constants, please!
#include "flume_const.h"

#define ALLOW_STDERR 1
//#define CHECK_CTLSOCK_CONN 1
#define CHECK_MMAP 1

#define N_EXEC_FDS 0x10
typedef struct {
  flume_confinement_t _confinement;
  int _in_exec;

  /*
   * the process can have some FDs open during exec, and additional opens
   * of those files will be permitted.  Please excuse the hard-coded
   * limit, but that should be plenty.
   */
  int _open_fds[N_EXEC_FDS];
  int _open_fds_endpost; // &{this_field} is the end of the above array
  int *_open_fds_cursor;


} flume_security_t;

#undef N_EXEC_FDS

static int secondary;

static void 
flume_clear_fds (flume_security_t *tsec)
{
  memset ((void *)tsec->_open_fds, 0, sizeof (tsec->_open_fds));
  tsec->_open_fds_cursor = tsec->_open_fds;
}

static int fd_stat (struct task_struct *task, int fd, struct kstat *stat)
{
  struct fdtable *fdt;
  struct file *filp;
  int error = -EBADF;
  
  fdt = files_fdtable (task->files);
  if (fd >= fdt->max_fds) {
    printk (KERN_INFO "%s: invalid fd (%d) (too large) for pid %u\n", 
            __FUNCTION__, fd, task->pid);
    return -1;
  }

  if (!(filp = fdt->fd[fd])) {
    printk (KERN_INFO "%s: invalid fd (%d) (no exist) for pid %u\n", 
            __FUNCTION__, fd, task->pid);
    return -1;
  }

  if ((error = vfs_getattr (filp->f_vfsmnt, filp->f_dentry, stat))) {
    printk (KERN_INFO "%s: error %d getting inode attributes for "
	    "fd (%d) for pid %u\n", 
            __FUNCTION__, error, fd, task->pid);
    return -1;
  }
  return 0;
}

/*
 * assumption:
 *   We hold cli_task->files->file_lock
 *   We do **not** hold rm_task->files->file_lock
 * return:
 *   0 if assumption holds, and -1 otherwise.
 */
static int
verify_ctl_sock (struct task_struct *rm_task, int rm_fd,
		 struct task_struct *cli_task, int cli_fd)
{
  struct kstat cli_stat, rm_stat;
  struct fdtable *rm_fdt, *cli_fdt;
  struct file *rm_filep, *cli_filep = NULL;
  struct sock *rm_sock, *cli_sock;
  int c;
  int rc = -1;

  if (fd_stat (cli_task, cli_fd, &cli_stat) < 0)  {
    /* noop */
  } else if (!S_ISSOCK (cli_stat.mode)) {
    printk (KERN_INFO "%s: client passed invalid client_ctlsock (%d)"
	    " (not SOCK type)\n", 
            __FUNCTION__, cli_fd);
  } else {
   
    spin_lock (&rm_task->files->file_lock);

    // This block protected with the above spin lock!
    do {
      
      if (fd_stat (rm_task, rm_fd, &rm_stat) < 0) {
	/* noop */
      } else if (!S_ISSOCK (rm_stat.mode)) {
	printk (KERN_INFO "%s: rm passed invalid rm_ctlsock (%d)"
		" (not SOCK type)\n", 
		__FUNCTION__, rm_fd);
      } else {
	
	rm_fdt = files_fdtable (rm_task->files);
	cli_fdt = files_fdtable (cli_task->files);
	rm_filep = rm_fdt->fd[rm_fd];
	cli_filep = cli_fdt->fd[cli_fd];
	
	rm_sock = ((struct socket *) rm_filep->private_data)->sk;
	cli_sock = ((struct socket *) cli_filep->private_data)->sk;
	if ((unix_sk (rm_sock)->peer != cli_sock) || 
	    (unix_sk (cli_sock)->peer != rm_sock)) {
	  printk (KERN_INFO "%s: client_ctlsock (%d) does not match"
		  " rm_ctlsock (%d)\n", 
		  __FUNCTION__, cli_fd, rm_fd);
	} else {
	  // Success at last!
	  rc = 0;
	}
      }
    } while (0);

    spin_unlock (&rm_task->files->file_lock);
  }


  if (rc == 0 && cli_filep) {
    // Check that there is only one reference to client side of the ctlsock 
    // file descriptor.  The RM will need to make sure it is not in the 
    // middle of sending a new control socket
    // or copying a control socket when calling closed_files.
    if ((c = atomic_read (&cli_filep->f_count)) > 1) {
      printk (KERN_INFO "%s: client_ctlsock (%d) has too many "
	      "references (%d)\n", 
	      __FUNCTION__, cli_fd, c);
      rc = -1;
    }
  }

  return rc;
}

static int
verify_no_open_files (int ok_fd, int pid, struct task_struct *cli)
{
  struct fdtable *fdt;
  int i;
  int rc = 0;

  fdt = files_fdtable (cli->files);
  for (i = 0; i < fdt->max_fds; i++) {
    if (fdt->fd[i] && i != ok_fd) {
      printk (KERN_INFO "%s: pid=%d has fd=%d open!\n",
	      __FUNCTION__, pid, i);
      rc = -1;
    }
  }
  return rc;
}

static int
verify_no_wmmap (int pid, struct task_struct *cli)
{
  struct vm_area_struct *mma;
  int rc = 0;

  // MK 7.27.2008 -- Anything SHARED is bad, since a process can always
  // mprotect() to change from READABLE to WRITABLE.  This unfortunately
  // means we need to patch glibc to never use SHARED, which it doesn't
  // with the exception of gconv.  A more extreme solution would be
  // to rewrite mmap() and mmap2() to rewrite the args.
  int bad_vm = /* VM_WRITE | */ VM_SHARED;

  for (mma = cli->mm->mmap; mma; mma = mma->vm_next) {
    if (mma->vm_file && ((mma->vm_flags & bad_vm) == bad_vm)) {
      rc = -1;
      printk (KERN_INFO "%s: found writable mmap region for pid=%d\n", 
	      __FUNCTION__, pid);
    }
  }
  return rc;
}

static int
flume_handle_confine_me (int cli_pid, int cli_fd,  int rm_fd)
{
  int rc = -1;
  struct task_struct *cli_task;
  struct task_struct *rm_task = current;
  flume_security_t *sec;

  rcu_read_lock ();

  if (!(cli_task = find_task_by_pid (cli_pid))) {
    printk (KERN_INFO "%s: could not find task for pid %d\n",
	    __FUNCTION__, cli_pid);
  } else {
   
    spin_lock (&cli_task->files->file_lock);
    
    // This block protected with the above spin lock.
    do { 

      // Note that verify_ctl_sock also spin locks rm_task->files->file_lock
      if (verify_ctl_sock (rm_task, rm_fd, cli_task, cli_fd) < 0) {
	printk (KERN_INFO "%s: failed to verify ctl_sock for pid=%d\n",
		__FUNCTION__, cli_pid);
      } else if (verify_no_open_files (cli_fd, cli_pid, cli_task) < 0) {
	printk (KERN_INFO "%s: pid=%d has open files!\n",
		__FUNCTION__, cli_pid);
      } else if (verify_no_wmmap (cli_pid, cli_task) < 0) {
	printk (KERN_INFO "%s: pid=%d has mmap'ed regions!\n",
		__FUNCTION__, cli_pid);
      } else {
	// Success! Set the confine bit on the process.
	sec = (flume_security_t *)cli_task->security;
	sec->_confinement = FLUME_CONFINE_ENFORCED;
	rc = 1;
      }
    } while (0);

    spin_unlock (&cli_task->files->file_lock);
  }

  rcu_read_unlock ();
  return rc;
}

static int
flume_handle_closed_files (int client_pid, int client_ctlsock, int rm_ctlsock) 
{
  int rc = -1, i;
  struct task_struct *task;
  struct fdtable *fdt;
  struct kstat stat;
  int error = -EBADF;
#ifdef CHECK_MMAP
  struct vm_area_struct *mma;
#endif
     
  // Check that <client_pid> is actually on the other side of <rm_ctlsock>.

  // RM will need to atomically call FLUME_PRCTL_CLOSED_FILES and remove the 
  // endpoints atomically. (The client should not be able to get to FDs 
  // between the two operations)
  
  // RCU Locks are enough to ensure the PID is correct: an adversary
  // could try to create a new process with the same PID (on a
  // different CPU), but the new process will not have the same
  // control socket to RM, so its end-points would not be affected by
  // the call to flume_closed_files.
  rcu_read_lock(); 

  // Combines find_pid and pid_task, so we don't have to worry about
  // exporting weird symbols, etc.
  task = find_task_by_pid (client_pid);
  if (!task) {
    printk (KERN_INFO "%s: could not find task_struct for client_pid %u\n", 
            __FUNCTION__, client_pid);
    goto done1;
  }

  spin_lock (&task->files->file_lock);

#ifdef CHECK_CTLSOCK_CONN
  if (verify_ctl_sock (current, rm_ctlsock, task, client_ctlsock) < 0)
    goto done3;
#endif /* CHECK_CTLSOCK_CONN */
  
  fdt = files_fdtable (task->files);
  // Check that <client_pid> has no open files other than the RM socket.
  for (i=0; i<fdt->max_fds; i++) {
    struct file *f;
    if ((f = fdt->fd[i])) {

      if ((error = vfs_getattr (f->f_vfsmnt, f->f_dentry, &stat))) {
        printk (KERN_INFO "%s: error %d getting inode attributes "
		"for client fd %d\n", 
                __FUNCTION__, error, i);
        goto done3;
      }

      if (S_ISREG (stat.mode) || S_ISLNK (stat.mode) || S_ISDIR (stat.mode)) {
        printk (KERN_INFO "%s: client pid %u failed closed_files "
		"check on fd %d\n", 
                __FUNCTION__, client_pid, i);
        goto done3;
      }
    }
  }

#ifdef CHECK_MMAP
  // Check that <client_pid> has no writable mmapped regions.
  mma = task->mm->mmap;
  while (mma) {
    if (mma->vm_file) {
      printk (KERN_INFO "%s: client pid %u failed closed_files "
              "check, has an mmapped file\n", 
              __FUNCTION__, client_pid);
      goto done3;
    }
    
    printk (KERN_INFO "%s: client pid %u mma %p vm_file %p\n", 
            __FUNCTION__, client_pid, mma, mma->vm_file);
    mma = mma->vm_next;
  }
#endif

  rc = 1; // Passed all the checks
  
 done3:
  spin_unlock(&task->files->file_lock);  
 done1:
  rcu_read_unlock();
  return rc;
}

static void
flume_init_security (flume_security_t *tsec)
{
  tsec->_confinement = FLUME_CONFINE_NONE;
  tsec->_in_exec = 0;
  flume_clear_fds (tsec);
}

static int
flume_task_alloc_security (struct task_struct *tsk)
{
  flume_security_t *tsec = kzalloc (sizeof (flume_security_t), GFP_KERNEL);
  if (!tsec)
    return -ENOMEM;
  flume_init_security (tsec);
  tsk->security = tsec;
  return 0;
}

static int
is_confined (void)
{
  flume_security_t *tsec = current->security;
  return (tsec && tsec->_confinement != FLUME_CONFINE_NONE);
}

static int
flume_bprm_alloc_security (struct linux_binprm *bprm)
{
  flume_security_t *tsec = current->security;
  int *i;

  if (tsec) {
    if (tsec->_confinement != FLUME_CONFINE_NONE) {

      /* 
       * just allocate something; if we fail to allocate something,
       * then the corresponding free will not be called;  it's useful
       * to use alloc/free for judging when a process starts to exec
       * and finishes exec, since it's a convenient bookend, though
       * we could have used something else...
       */
      i = kzalloc (sizeof (int), GFP_KERNEL);
      if (!i) 
	return -ENOMEM;
      *i = 1;

      bprm->security = i;
    }

    // Might already be set, but set again...
    tsec->_in_exec = 1;
  }
  return 0;
}

static void
flume_bprm_free_security (struct linux_binprm *bprm)
{
  flume_security_t *tsec = current->security;
  int *i = bprm->security;
  bprm->security = NULL;
  if (i)
    kfree (i);

  if (tsec)
    tsec->_in_exec = 0;
}

static int syscall_ok (void) { return is_confined () ? -1 : 0 ; }

static int dummy (const char *func) {
  if (syscall_ok () < 0) {
    printk (KERN_INFO "%s: rejected, stacktrace:\n", func);
    dump_stack ();
    return -1;
  } else {
    return 0;
  }
}

static int flume_task_getpgid (struct task_struct *x) { 
  return dummy (__FUNCTION__); 
}
static int flume_task_getsid (struct task_struct *x) { 
  return dummy (__FUNCTION__); 
}
static int flume_ptrace (struct task_struct *parent, struct task_struct *child) { 
  return dummy (__FUNCTION__); 
}
static int flume_sysctl (struct ctl_table * table, int op) { 
  return dummy (__FUNCTION__); 
}
static int flume_quotactl (int cmds, int type, int id, struct super_block *sb) { 
  return dummy (__FUNCTION__); 
}
static int flume_quotaon (struct dentry * dentry) { 
  return dummy (__FUNCTION__); 
}
static int flume_inode_create (struct inode *dir, struct dentry *dentry, 
			       struct vfsmount *mnt, int mode) { 
  return dummy (__FUNCTION__); 
}
static int flume_task_setnice (struct task_struct *p, int nice) { 
  return dummy (__FUNCTION__); 
}
static int flume_task_setrlimit (unsigned int resource, struct rlimit *new_rlim) { 
  return dummy (__FUNCTION__); 
}

static int flume_ipc_permission (struct kern_ipc_perm *ipcp, short flag)
{
  return dummy (__FUNCTION__);
}

static int flume_socket_connect (struct socket *a, struct sockaddr *b, int c)
{
  return dummy (__FUNCTION__);
}

static int flume_socket_bind (struct socket *a, struct sockaddr *b, int c)
{
  return dummy (__FUNCTION__);
}

static int flume_socket_create (int family, int type, int protocol, int kern)
{
  return dummy (__FUNCTION__);
}

#ifdef HAVE_FLUME_GETPID_PROTECTION
static int flume_task_getpgid_self (void) { return dummy (__FUNCTION__); }
static int flume_task_getsid_self (void) { return dummy (__FUNCTION__); }
static int flume_task_getppid (void) { return dummy (__FUNCTION__); }
static int flume_task_getpid (void) { return dummy (__FUNCTION__); }
#endif /* HAVE_FLUME_GETPID_PROTECTION */


static int
flume_putfd (flume_security_t *tsec, int i)
{
  int rc = 0;
  if (tsec->_open_fds_cursor < &tsec->_open_fds_endpost) {
    *tsec->_open_fds_cursor++ = i;
  } else {
    rc = -1;
  }
  return rc;
}

static void
flume_task_free_security (struct task_struct *tsk)
{
  flume_security_t *tsec = tsk->security;
  tsk->security = NULL;
  if (tsec) 
    kfree (tsec);
}

static int
flume_task_prctl (int option, unsigned long arg2, unsigned long arg3,
		 unsigned long arg4, unsigned long arg5)
{
  flume_security_t *tsec = current->security;
  pid_t pid = current->pid;
  int rc = 0;
  int confinement, fd, in_exec;

  switch (option) {
  case FLUME_PRCTL_ENABLE:
    if (!tsec) {
      printk (KERN_INFO "%s: no tsec field on process: %u\n", 
	      __FUNCTION__, pid);
      rc = -1;
      break;
    }

    confinement = (int)arg2;
    in_exec = (int)arg3;
    if (confinement > tsec->_confinement) {
      tsec->_confinement = confinement;
      tsec->_in_exec = in_exec;
      rc = 1;
    } else {
      printk (KERN_INFO "%s: can't disable trace on process "
              "(%d vs %d): %u\n",
              __FUNCTION__, confinement, tsec->_confinement, pid);
      rc = -1;
    }
    break;

  case FLUME_PRCTL_PUTFD:
    if (!tsec) {
      printk (KERN_INFO "%s: no tsec field on process: %u\n", 
	      __FUNCTION__, pid);
      rc = -1;
      break;
    }

    fd = (int)arg2;
    if (fd < 0) {
      printk (KERN_INFO "%s: bad putfd given for process %u\n",
              __FUNCTION__, pid);
      rc = -1;
    } else if ((rc = flume_putfd (tsec, fd)) < 0) {
      printk (KERN_INFO "%s: cannot fit anymore FDs into process %u\n",
              __FUNCTION__, pid);
    } else {
      rc = 1;
    }
    break;

  case FLUME_PRCTL_CLOSED_FILES:
    rc = flume_handle_closed_files (arg2, arg3, arg4);
    break;

  case FLUME_PRCTL_CONFINE_ME:
    rc = flume_handle_confine_me (arg2, arg3, arg4);
    break;

  default:
    break;
  }

  return rc;
}

static int
flume_inode_eq (const struct inode *i1, const struct inode *i2)
{
  return ((i1->i_ino == i2->i_ino) && 
	  (i1->i_rdev == i2->i_rdev) &&
	  (i1->i_generation == i2->i_generation) ? 1 : 0);
}

static int
flume_inode_permission (struct inode *inode, int mask, struct nameidata *nd)
{
  pid_t pid = current->pid;
  flume_security_t *tsec;
  int *fd;
  int ret;
  int tries = 0;
  int isdir = 0;

  tsec = current->security;
  if (tsec && tsec->_confinement == FLUME_CONFINE_ENFORCED) {
    int isdir = S_ISDIR (inode->i_mode);
    if (tsec->_in_exec) {

      if (isdir) {
	ret = 0;
      } else if (mask & MAY_WRITE) {
	ret = -1;
      } else {
	ret = -1;
	
	for (fd = tsec->_open_fds; 
	     fd < tsec->_open_fds_cursor && ret < 0; 
	     fd++) {
	  struct file *f2 = fget (*fd);
	  tries ++;
	  if (f2 && flume_inode_eq (inode, f2->f_dentry->d_inode)) {
	    ret = 0;
	  }
          fput (f2);
	}
      }
    } else {
      ret = -1;
    }
  } else {
    ret = 0;
  }

  if (ret == -1) {
    printk (KERN_INFO "%s: failed inode access: pid=%u, inode=%lx, mask=%x, "
	    "tries=%d, ret=%d, isdir=%d, in_exec=%d\n",
	    __FUNCTION__, pid, inode->i_ino, mask, tries, ret, 
	    isdir, tsec->_in_exec);

    printk ("Showing stack trace to find problem...\n");
    dump_stack ();

    printk ("I can abort the process, but I won't....\n");

    if (0) {
      // XXX Disable confinement so we can dump core (debug)
      if (tsec) 
	tsec->_confinement = 0;
      
      send_sig (SIGSEGV, current, 0);
    }

  }

  return ret;
}

static int
flume_register_security (const char *name, struct security_operations *ops)
{
  printk (KERN_INFO "%s: registering security module: %s\n",
	  __FUNCTION__, name);
  return 0;
}

static int
flume_unregister_security (const char *name, struct security_operations *ops)
{
  printk (KERN_INFO "%s: unregistering security module: %s\n",
	  __FUNCTION__, name);
  return 0;
}

static int
flume_bprm_check_security (struct linux_binprm *bprm)
{
  // Game plan:
  //   1. Look in bprm for env variables (need to poke in stack)
  //   2. Call struct file * f = fget (fd); to get file struct
  //   3. Compare bprm->file->f_dentry->d_inode->(i_ino,i_rdev)
  //      to that of f.
  //   4. Return -1 if no match.
  //   5. Turn off all subsequent files opens, except for the registered
  //      ld.so, so that exec cannot deliver any new files. Note that
  //      all code in the various binfmts call open_exec(), which calls
  //      vfs_permission, which calls permission, which calls security_
  //      inode_permission, which calls into the LSM.  This should
  //      be sufficient...

  return 0;
}

/*
 * make a struct with all of the necessary hooks; it's OK to leave the
 * rest out, as they are set to reasonable defaults on install.
 */
static struct security_operations flume_ops = {

  /* Inode Hooks */
  .inode_permission =    flume_inode_permission,
  .inode_create     =    flume_inode_create,

  /* Task Hooks */
  .task_alloc_security = flume_task_alloc_security,
  .task_free_security =  flume_task_free_security,
  .task_prctl =          flume_task_prctl,

  .task_getpgid        = flume_task_getpgid,
  .task_getsid         = flume_task_getsid,
  .task_setnice        = flume_task_setnice,
  .task_setrlimit      = flume_task_setrlimit,

  /* System V IPC 
   * XXX - experimental - might disable pipes!
   * Probably not, though.
   */
  .ipc_permission      = flume_ipc_permission,

#ifdef HAVE_FLUME_GETPID_PROTECTION
  .task_getpgid_self   = flume_task_getpgid_self,
  .task_getsid_self    = flume_task_getsid_self,
  .task_getpid         = flume_task_getpid,
  .task_getppid        = flume_task_getppid,

#endif /* HAVE_FLUME_GETPID_PROTECTION */

  /* Bprm Hooks (for exec/fexec) */
  .bprm_check_security = flume_bprm_check_security,
  .bprm_alloc_security = flume_bprm_alloc_security,
  .bprm_free_security = flume_bprm_free_security,

  /* network */

  .socket_connect    = flume_socket_connect,
  .socket_bind       = flume_socket_bind,
  .socket_create     = flume_socket_create,

  /* other stuff */
  .ptrace      = flume_ptrace,
  .sysctl      = flume_sysctl,
  .quotactl    = flume_quotactl,
  .quota_on    = flume_quotaon,

  /* register + unreg */
  .register_security   = flume_register_security,
  .unregister_security = flume_unregister_security

};

static __init int 
flume_init (void)
{
  if (register_security (&flume_ops)) {
    if (mod_reg_security (KBUILD_MODNAME, &flume_ops)) {
      printk (KERN_ERR "Flume: Unable to register with primary "
	      "security module\n");
      return -EINVAL;
    }
    secondary = 1;
  }
  printk (KERN_INFO "Flume LSM initialized%s\n",
	  secondary ? " as a secondary" : "");
  return 0;
}

static void __exit flume_exit (void)
{
  if (secondary) {
    if (mod_unreg_security (KBUILD_MODNAME, &flume_ops)) {
      printk (KERN_ERR "Flume: Unable to unregister with primary "
	      "security module\n");
      return;
    }
  }

  if (unregister_security (&flume_ops)) {
    printk (KERN_ERR "Flume: Unable to unreg with kernel\n");
  } else {
    printk (KERN_INFO "Flume LSM removed\n");
  }

}

security_initcall (flume_init);
module_exit (flume_exit);

MODULE_DESCRIPTION("Flume Security Module");
MODULE_LICENSE("GPL");
