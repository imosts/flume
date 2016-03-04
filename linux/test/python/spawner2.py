
"""
spawner2.py

    Tries to exercise parent/child endpoints + spawn.
"""

import sys
import os
import flume.flmos as flmo
import flume.util as flmu
import flume as flm
import os.path
import getopt
import time

def usage ():
    print """usage: spawner2 [-E]"""
    sys.exit (2)
    

def main ():

    do_endpoint = True 
    
    prefix = os.path.dirname (sys.argv[0])
    
    try:
        short_opts = "hE"
        long_opts = [ "help", "no-endpoint-change" ]
        opts, args = getopt.getopt (sys.argv[1:], short_opts, long_opts)
        for o,a in opts:
            if o in ("-E", "--no-endpoint-change"):
                do_endpoint = False
            else:
                usage ()
    except getopt.GetoptError:
        usage ();

    #
    # Make a new export-protection tag
    #
    (ep_h,ep_c) = flmu.makeTag ("ep", "spawner2")
    
    #
    # Make two sockerpairs -- one for child's stdin and one for its
    # stdout.
    #
    claim_h = []
    for i in range(2):
        (fd, h) = flmo.socketpair ()
        claim_h += [ h ]

    argv =  [ sys.executable,
              prefix + "/spawnee2.py",
              ep_h.armor32() ]

    endpoint = flmo.Endpoint (S = flmo.Label ([ep_h]))

    # set an endpoint for this child so we can hear what it's saying
    flmo.set_fd_label (flm.LABEL_S, fd, endpoint.get_S ())

    if not do_endpoint:
        endpoint = None
            
    (ch,_) = flmo.spawn2 (prog=argv[0],
                          argv=argv,
                          confined=True,
                          claim = claim_h,
                          endpoint=endpoint)
    
    print "spawn gave ch=" + str (ch)
    fh = os.fdopen (fd, "r")
    print "read from child: " +  fh.read ().strip ()
    
    (pid, status, visible) = flmo.waitpid ()
    print "wait returned: %s,%d,%d" % (str (pid), status, visible)

##-----------------------------------------------------------------------
##-----------------------------------------------------------------------

main()
    
