
"""
fork.py

    Tries to fork a new flume child.
"""

import flume.flmos as flmo
import flume.util as flmu
import sys
import os


def main ():

    print "Starting up!"

    names = [ 'stdin', 'stdout', 'stderr' ]

    close_fds = [ x.fileno () for x in [ sys.stdin, sys.stdout, sys.stderr ] ]
    #close_fds += [ 3,4,5,6 ]

    sockets = [ f(names[i]) for (i,f) in 
                enumerate ( [flmo.wpipe, flmo.rpipe, flmo.rpipe ] ) ]

    close_fds += [ p[0] for p in sockets ]
    
    print "Calling fork!"
    chld = flmo.fork (close_fds, True)

    if chld == 0:
        for (i,n) in enumerate (names):
            flmo.claim (sockets[i][1], n)
        print "hello parent; my pid=%d\n" % os.getpid ()
    else:
        print "Child pid=%d" % chld
        chld_out = os.fdopen (sockets[1][0])
        print 'Word from child: ' +  chld_out.readline ()
        

main ()
