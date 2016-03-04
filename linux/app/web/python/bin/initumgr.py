
# This script creates the user manager's principal, meaning its home
# directory and contents.

import flmw
import flmw.usermgr
import sys

def usage ():
    print "usage: " + sys.argv[0] 
    sys.exit (1)

if len (sys.argv) != 1:
    usage ()

umgr = flmw.usermgr.UserMgr ()
(p, t, d, i) = umgr.initPrincipal ()
    
print "initialization succeeded; tag= " + t.armor32 ()  \
      + " [ " + str (t) + " ]"
print "  pw=" + p
print "  homedir=" + d
print "  UserID=" + i
