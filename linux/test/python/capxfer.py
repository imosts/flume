

import sys
import os
import flume.flmos as flo
import flume.util as flu
import flume as flm
import os.path


def main ():

    prefix = os.path.dirname (sys.argv[0])

    child_pipes = [ flo.socketpair () for i in range (2) ]
    child_fds = [ p[0] for p in child_pipes ]
    claim_h = [ p[1] for p in child_pipes ]
    
    #child_fh[0] = 
    #child_fh[1] = os.fdopen (child_fds[1], "r")
    #fd_modes = "wr"
    #child_fh = [ os.fdopen(fd, fd_modes[i]) 
    #             for i,fd in enumerate (child_fds)]

    argv =  [ sys.executable,
              prefix + "/capxferee.py"
              ]

    (ch,_) = flo.spawn2 (prog=argv[0],
                          argv=argv,
                          confined=True,
                          claim=claim_h)

    # make some capabilities to play around with. Do so after the
    # spawn!!
    caps = [ flu.makeTag ("w", "capxfer capability%d" % i)[1][0] 
             for i in range(3) ]
    
    print "spawn gave ch=" + str (ch)

    child_fh = [ os.fdopen (child_fds[i], m) for i,m in enumerate ("wr") ]

    # Wait for child to say something
    print "reading from child: %s" % child_fh[1]
    print "read from child: " +  child_fh[1].readline ().strip ()

    # Now send capabilities to him

    cos = flo.CapabilityOpSet ( 
        [ flo.CapabilityOp (caps[0], flm.CAPABILITY_GRANT),
          flo.CapabilityOp (caps[1], flm.CAPABILITY_SHOW)
          ])

    print "Sending capabilities: %s" % cos
    flo.send_capabilities (child_fds[0], cos)

    # tell him what we've sent
    s = ",".join ([ c.armor32 () for c in caps ])
    print "Sending names (%s)" % s
    child_fh[0].write (s + "\n")
    child_fh[0].flush ()

    # Wait for him to say what happend
    print "read from child: " + child_fh[1].readline ().strip()
    
    # Now he should exit
    (pid, status, visible) = flo.waitpid ()
    print "wait returned: %s,%d,%d" % (str (pid), status, visible)


main ()
