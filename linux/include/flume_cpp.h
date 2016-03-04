
/*
 * Preprocessor Macros for Flume, that can be used conveniently in 
 * C and C++ languages.
 */

#ifndef _FLUME_CPP_H_
#define _FLUME_CPP_H_

#include "flume_const.h"

#define INFINITY_STR "all"

#define FLUME_DEFAULT_SOCKET "/tmp/flumerm-sock";

#define LD_LIBRARY_PATH "LD_LIBRARY_PATH"

#include <limits.h>

/* Linux doesn't seem to be able to include this, so let's just copy
 *  it in
 */
#ifndef  ULLONG_MAX
# define ULLONG_MAX   18446744073709551615ULL
#endif

/* Set to 1 to allow safe processes to print to stderr */
#define FAKE_SAFE_MODE 0

#define STDIN 0
#define STDOUT 1
#define STDERR 2


#define NFEXEC 213

#define FEXECVE(fd,path,ifd,ipath,argv,envp) \
  syscall (NFEXEC, fd, path, ifd, ipath, argv, envp)


#endif /* _FLUME_CPP_H_ */
