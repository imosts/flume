
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

def usage ():
    print """usage: spawner2 [-E]"""
    sys.exit (2)
    

def main ():

    do_endpoint = True
    n_changes = 0
    
    prefix = os.path.dirname (sys.argv[0])
    
    try:
        short_opts = "hEn:"
        long_opts = [ "help", "no-endpoint-change", "num-changes=" ]
        opts, args = getopt.getopt (sys.argv[1:], short_opts, long_opts)
        for o,a in opts:
            if o in ("-E", "--no-endpoint-change"):
                do_endpoint = False
            elif o in ("-n", "--num-changes"):
                try:
                    n_changes = int (a)
                    
                    if n_changes < 0 or n_changes > 4:
                        print "N-changes should in [0,4)"
                        usage ()
                    
                except TypeError, e:
                    print "Cannot convert to int: " + a
                    usage ()
            else:
                usage ()
    except getopt.GetoptError:
        usage ();

    #
    # Make a new export-protection tag
    #
    tags = [ flmu.makeTag ("ep", "spawner3-%d" % i)[0] for i in range (4) ]

    print "Spawner3: O=%s" % str(flmo.get_label (flm.LABEL_O))
    
    #
    # Make two sockerpairs -- one for child's stdin and one for its
    # stdout.
    #
    claim_h = []
    for i in range(2):
        (fd, h) = flmo.socketpair ()
        claim_h += [ h ]

    argv =  [ sys.executable, prefix + "/spawnee3.py" ]
    
    # load all tags into the endpoint, just to make sure.
    endpoint = flmo.Endpoint (S = flmo.Label ( tags ))

    # set an endpoint for this child so we can hear what it's saying
    flmo.set_fd_label (flm.LABEL_S, fd, endpoint.get_S ())

    if not do_endpoint:
        endpoint = None

    #
    # Make a label change sequence that first empties our O, then
    # sets S to be [t1], [t1,t2,t3], [t1,t2].  Of course the
    # third label change should fail.
    #
    lcl = [ flmo.LabelChange (lab = flmo.Label (), which = flm.LABEL_O) ] +\
        [ flmo.LabelChange ( lab = flmo.Label ( l ), which = flm.LABEL_S )
          for l in [ tags[0:1], tags[0:3], tags[0:2] ] ]

    lcs = flmo.LabelChangeSet( lcl[0:n_changes] )

    print "Launching child with label change set: %s" % lcs

    (ch,rc) = flmo.spawn2 (prog=argv[0],
                           argv=argv,
                           confined=True,
                           claim = claim_h,
                           endpoint=endpoint,
                           lchanges = lcs)
    
    print "spawn gave ch=" + str (ch)
    
    if rc == flm.SPAWN_OK:
        
        print "Child is visible!"
        
        fh = os.fdopen (fd, "r")
        print "read from child: " +  fh.read ().strip ()
        
        (pid, status, visible) = flmo.waitpid ()
        print "wait returned: %s,%d,%d" % (str (pid), status, visible)
        
    else:
        
        print "Child proc is invisible, so exiting"

##-----------------------------------------------------------------------
##-----------------------------------------------------------------------

main()
    
