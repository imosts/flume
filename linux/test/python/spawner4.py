
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
    print """usage: spawner2 [-f]"""
    sys.exit (2)
    

def main ():

    fail = False

    try:
        short_opts = "hf"
        long_opts = [ "help", "fail" ]
        opts, args = getopt.getopt (sys.argv[1:], short_opts, long_opts)
        for o,a in opts:
            if o in ("-f", "--fail"):
                fail = True
            else:
                usage ()
    except getopt.GetoptError:
        usage ();

    prefix = os.path.dirname (sys.argv[0])
    
    #
    # Make a new export-protection tag
    #
    t1,caps = flmu.makeTag ("ep", "spawner4-1")
    t1c = caps[0]
    t2,_ = flmu.makeTag ("ep", "spawner4-1")

    print "Spawner4: O=%s" % str(flmo.get_label (flm.LABEL_O))
    
    #
    # Make two sockerpairs -- one for child's stdin and one for its
    # stdout.
    #
    claim_h = []
    for i in range(2):
        (fd, h) = flmo.socketpair ()
        claim_h += [ h ]

    argv =  [ sys.executable, prefix + "/spawnee4.py" ]

    # child needs to keep an empty endpoint around so it can always
    # talk to the parent, who doesn't change his label
    ch_endpoint = flmo.Endpoint (S = flmo.Label () )

    #
    # Make a label change sequence that first empties our O, then
    # sets S to be [t1], [t1,t2,t3], [t1,t2].  Of course the
    # third label change should fail.
    #
    lcl = [ flmo.LabelChange (lab = flmo.Label ([t1c]), which = flm.LABEL_O),
            flmo.LabelChange (lab = flmo.Label ([t1]), which = flm.LABEL_S),
            flmo.LabelChange (lab = flmo.Label ([t1,t2]), which = flm.LABEL_S) ]

    lim = 2
    if fail:
        lim = 3
    
    lcs = flmo.LabelChangeSet( lcl[0:lim] )

    print "Launching child with label change set: %s" % lcs

    try:

        (ch,rc) = flmo.spawn2 (prog=argv[0],
                               argv=argv,
                               confined=True,
                               claim = claim_h,
                               ch_endpoint = ch_endpoint,
                               lchanges = lcs)
    except flm.PermissionError, e:
        rc = 0
        if fail:
            print "Good! Got Permission error: " + str (e)
        else:
            print "Uh-oh!  Unexpected problem: " + str (e)
            rc = 2
        sys.exit (rc)
    
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
    
