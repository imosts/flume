#!/usr/bin/env python

import sys

tups = [ ( 'i', "INTERCEPT"   ),
         ( 'm', "MEMORY"      ),
         ( 'l', "LIBC"        ),
         ( 'c', "CONNECT"     ),
         ( 'e', "FEXEC"       ),
         ( 'C', "CLNT"        ),
         ( 's', "SESS"        ),
         ( 'k', "LINKER"      ),
         ( 'a', "CLNT_ANY"    ),
         ( 'j', "JAIL"        ),
         ( 'p', "FD_PASSING"  ),
         ( 'h', "HLP_STATUS"  ),
         ( 'S', "SOCKETS"     ),
         ( 'f', "FS"          ),
         ( 'P', "PROCESS"     ),
         ( 'R', "RPC"         ),
         ( 'x', "PROXY"       ),
         ( 'L', "LABELOPS"    ),
         ( 'F', "FDS"         ),
         ( 'w', "SPAWN"       ),
         ( 'H', "CACHE"       ),
         ( 'A', "SRV_ANY"     ) ]

first_server_opt = 'j'

s = set ()
bad = False
for f in [ t[0] for t in tups ]:
    if f in s:
        sys.stderr.write ("Generator warning: Duplicated flag: '%s'\n" % f)
        bad = True
    else:
        s.add (f)

if bad:
    sys.exit (1)

optstr = ''.join ([ t[0] for t in tups ])

pdict = { "optstr" : optstr }

print """
#include "async.h"
#include "flume_ev_debug.h"
#ifndef __STDC_FORMAT_MACROS
# define __STDC_FORMAT_MACROS
#endif
#include <inttypes.h>

static void
usage ()
{
   warnx << "usage: " << progname << " [-%(optstr)s]\\n"
         << "  Flags:\\n"
         << "    Client/libc:\\n";
""" % pdict

for t in tups:
    if (t[0] == first_server_opt):
        print '  warnx << "\\n";'
        print '  warnx << "    Server:\\n";'
    print """  warnx << "\\t-%s\\t%s\\n";""" % t

print """
   exit (1);
}

static bool
handle_opt (int ch, u_int32_t *out_cli, u_int32_t *out_srv)
{
   switch (ch) {
"""

res = "out_cli"
for t in tups:
    if (t[0] == first_server_opt):
        res = "out_srv"
    print "   case '%s': *%s |= FLUME_DEBUG_%s; break;" % (t[0], res, t[1])

print """
   default:
      return false;
   }
   return true;
}

int
main (int argc, char *argv[])
{
   setprogname (argv[0]);
   int ch;
   u_int32_t out_cli = 0;
   u_int32_t out_srv = 0;
   const char *optstr = "%(optstr)s";

   while ((ch = getopt (argc, argv, optstr)) != -1) {
      if (!handle_opt (ch, &out_cli, &out_srv))
         usage ();
   }
   if (out_cli)
     fprintf (stdout, "%%s=0x%%" PRIx32 "\\n", FLUME_DBG_EV, out_cli);
   if (out_srv)
     fprintf (stdout, "%%s=0x%%" PRIx32 "\\n", FLUME_DBG_SRV_EV, out_srv);
}
""" % pdict
         
