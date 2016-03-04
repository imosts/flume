
#include "flume_features.h"

#include <stdlib.h>
#include <limits.h>
#include <stdio.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/time.h>
#include <errno.h>
#include <assert.h>

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <netinet/tcp.h>
#include <unistd.h>

#include "flume_prot.h"
#include "flume_libc_stubs.h"
#include "flume_api.h"
#include "flume_cpp.h"
#include "flume_debug.h"
#include "flume_sfs.h"
#include "flume_clnt.h"

#define SCRIPT_MAGIC "#!"
#define SCRIPT_MAGIC_LEN 2
#define MAXINTERP 1024
#define _PATH_DEFPATH "/usr/local/bin:/usr/bin:/bin"
#define _PATH_BSHELL "/bin/sh"

//
// XXX -- This should *not* be hardcoded; rather, it should be
// read from inside the file (if the file is an ELF, that is),
// but we leave that to future work.
//
#define LINKER_PATH "/lib/ld-linux.so.2"

extern char **environ;
static int
get_interp (int fd, char **interp, char **arg, char *scratch, 
	    size_t scratchlen)
{
  char *cp;

  ssize_t rc = read (fd, (void *)scratch, scratchlen - 1);

  if (rc < 0)
    return rc;
  scratch[rc] = 0;

  if (strncmp (scratch, SCRIPT_MAGIC, (size_t )SCRIPT_MAGIC_LEN))
    return -1;

  /* skip spaces between #! and shellname */
  for (cp = scratch + SCRIPT_MAGIC_LEN; *cp == ' ' || *cp == '\t'; cp++);


  if (!*cp)
    return -1;

  /* success from this point on.... */
  *interp = cp;
  *arg = NULL;

  /* advance to end of interpreter */
  for ( ; *cp != 0 && *cp != '\t' && *cp != '\n'; cp++);

  if (*cp) {

    /* null-terminate the interpreter */
    *cp++ = 0;
    
    /* skip spaces until next arg */
    for ( ; *cp == ' ' || *cp == '\t'; cp++);
    

    if (*cp) {
      *arg = cp;

      /* record the argument and null-terminate it */
      for ( ; *cp != 0 && *cp != '\n'; cp++);
      *cp ++ = 0;
    }
  }

  /* success */
  return 0;
}

int 
fexecve (int fd, const char *path, 
	 int interp_fd, const char *interp_path, 
	 char *const argv[], char *const envp [])
{
  int rc;
  rc = FEXECVE(fd, path, interp_fd, interp_path, argv, envp);
  return rc;
}

int
flume_execve (const char *path, char *const argv[], char *const envp[])
{
  char scratch[MAXINTERP];
  int fd;
  int rc;
  char *interp = NULL, *interp_arg = NULL;
  int linker_fd;
  char *const *p_c;
  char **p;
  int argc, new_argc;
  char ** new_argv = NULL;

  char outpath[PATH_MAX];
  char linker_outpath[PATH_MAX];

  FLUME_DEBUG(FLUME_DEBUG_LIBC, stderr, "execve modified!....\n");
  
  if (!path && !argv) {
    errno = EINVAL;
    return -1;
  }

  fd = flume_open_full (outpath, path, O_RDONLY, 0, NULL);
  path = outpath;

  /* count the # of args in the existing argv*/
  for (p_c = argv; *p_c; p_c++);
  argc = p_c - argv;

  if (fd < 0) return fd;
  rc = get_interp (fd, &interp, &interp_arg, scratch, MAXINTERP);
  FLUME_DEBUG(FLUME_DEBUG_LIBC, stderr, "get_interp: %d\n", rc);

  if (rc == 0) {
    close (fd);
    if ((fd = flume_open_full (outpath, interp, O_RDONLY, 0, NULL)) < 0) {
      return fd;
    }

    FLUME_DEBUG(FLUME_DEBUG_LIBC, stderr, "making the new argc and argv\n");
    /* add a couple more as required */
    new_argc = argc + 1 + (interp_arg ? 1 : 0);

    new_argv = (char **)malloc (sizeof (char*) * (new_argc + 1));
    p = new_argv;
    *p++ = outpath;
    if (interp_arg) *p++ = interp_arg;
    memcpy (p, argv, sizeof (char *) * argc);
    new_argv[new_argc] = 0;
    argv = new_argv;

  }

  FLUME_DEBUG(FLUME_DEBUG_LIBC, stderr, 
	     "trying to open the linker at %s\n", LINKER_PATH);
  fflush(stderr);

  if ((linker_fd = flume_open_full (linker_outpath, 
				   LINKER_PATH, O_RDONLY, 0, NULL)) < 0) {
    FLUME_DEBUG(FLUME_DEBUG_LIBC, stderr, 
	       "failed to open linker file %s\n", LINKER_PATH);
    return fd;
  }
   
  FLUME_DEBUG(FLUME_DEBUG_LIBC, stderr, "going for fexec\n");
  rc = fexecve (fd, path, linker_fd, linker_outpath, argv, envp);
  FLUME_DEBUG(FLUME_DEBUG_LIBC, stderr, 
	     "modified exec failed: %s\n", strerror (errno));
 
  /* only returns on failure. */
  assert (rc < 0);
  if (fd >= 0) close (fd);
  if (new_argv) free (new_argv);

  return rc;
}

int
flume_execvp(const char *name, char * const *argv)
{
	char **memp;
	int cnt, lp, ln, len;
	char *p;
	int eacces = 0;
	char *bp, *cur, *path, buf[MAXPATHLEN];

	/*
	 * Do not allow null name
	 */
	if (name == NULL || *name == '\0') {
		errno = ENOENT;
		return (-1);
 	}

	/* If it's an absolute or relative path name, it's easy. */
	if (strchr(name, '/')) {
		bp = (char *)name;
		cur = path = NULL;
		goto retry;
	}
	bp = buf;

	/* Get the path we're searching. */
	if (!(path = getenv("PATH")))
		path = _PATH_DEFPATH;
	len = strlen(path) + 1;
	cur = alloca(len);
	if (cur == NULL) {
		errno = ENOMEM;
		return (-1);
	}
	strncpy(cur, path, len);
	path = cur;
	while ((p = strsep(&cur, ":"))) {
		/*
		 * It's a SHELL path -- double, leading and trailing colons
		 * mean the current directory.
		 */
		if (!*p) {
			p = ".";
			lp = 1;
		} else
			lp = strlen(p);
		ln = strlen(name);

		/*
		 * If the path is too long complain.  This is a possible
		 * security issue; given a way to make the path too long
		 * the user may execute the wrong program.
		 */
		if (lp + ln + 2 > (int) sizeof(buf)) {
			struct iovec iov[3];

			iov[0].iov_base = "execvp: ";
			iov[0].iov_len = 8;
			iov[1].iov_base = p;
			iov[1].iov_len = lp;
			iov[2].iov_base = ": path too long\n";
			iov[2].iov_len = 16;
			(void)writev(STDERR_FILENO, iov, 3);
			continue;
		}
		bcopy(p, buf, lp);
		buf[lp] = '/';
		bcopy(name, buf + lp + 1, ln);
		buf[lp + ln + 1] = '\0';

retry:		(void)flume_execve(bp, argv, environ);
		switch(errno) {
		case E2BIG:
			goto done;
		case EISDIR:
		case ELOOP:
		case ENAMETOOLONG:
		case ENOENT:
			break;
		case ENOEXEC:
			for (cnt = 0; argv[cnt]; ++cnt)
				;
			memp = alloca((cnt + 2) * sizeof(char *));
			if (memp == NULL)
				goto done;
			memp[0] = "sh";
			memp[1] = bp;
			bcopy(argv + 1, memp + 2, cnt * sizeof(char *));
			(void)flume_execve(_PATH_BSHELL, memp, environ);
			goto done;
		case ENOMEM:
			goto done;
		case ENOTDIR:
			break;
		case ETXTBSY:
			/*
			 * We used to retry here, but sh(1) doesn't.
			 */
			goto done;
		case EACCES:
			eacces = 1;
			break;
		default:
			goto done;
		}
	}
	if (eacces)
		errno = EACCES;
	else if (!errno)
		errno = ENOENT;
done:
	return (-1);
}

