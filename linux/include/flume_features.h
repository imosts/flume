
/*
 * Include this .h first, to tell system files which features Flume needs.
 * 
 * This file is roughly in place of config.h, if we were to use autoconf.
 * 
 */

#ifndef _FLUME_FEATURES_H_
#define _FLUME_FEATURES_H_

#define _LARGEFILE64_SOURCE 1

// Use the pthreads system (try without PTH for ease of install)
#define HAVE_PTHREADS 1

// Use MYSQL Bind types
#define HAVE_MYSQL_BIND 1

#endif /* _FLUME_FEATURES_H_ */
