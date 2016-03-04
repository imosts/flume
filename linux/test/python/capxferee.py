import os
import sys

##
## Reenable at your own peril!
##
#sys.stderr.write ("XXXX " + str(os.access ("/", 0)) + "\n")
#sys.stderr.write (repr(os.environ)  + "\n")

import flume.flmos as flo
import flume as flm

def output (s):
    print s
    sys.stdout.flush ()


def main ():

    errors = []

    # Say hi to our parent
    output ("hello; I am the child; pid=%x" % os.getpid ())
    
    # Read the two capabilites from standard input
    s = sys.stdin.readline ().strip ()
    caps = [ flo.Handle (x) for x in s.split (',') ]

    # See if our O label was updated.
    o_pre = flo.get_label (flm.LABEL_O)


    #
    # Make 3 categorgies of operations: 
    #
    #   - succ: those that should succeed
    #   - fail: those on which ops have succeed, but the op in question
    #        ought to fail
    #   - noent: those that should not be reflected in the response.
    #
    suc = [ flo.CapabilityOp (caps[0], flm.CAPABILITY_TAKE),
            flo.CapabilityOp (caps[1], flm.CAPABILITY_VERIFY)
            ]

    fail = [ flo.CapabilityOp (caps[1], flm.CAPABILITY_TAKE) ]

    noent = [ flo.CapabilityOp (caps[2], flm.CAPABILITY_TAKE),
              flo.CapabilityOp (caps[2], flm.CAPABILITY_VERIFY) 
              ]

    cos = flo.CapabilityOpSet ( suc + fail + noent)

    # Now verify these capabilities. 
    out = flo.verify_capabilities (0, 0, cos)

    # Go ahead and check the outcome
    d = out.toDict ()
    for s in suc:
        if d[s.get_h()] != s.get_op ():
            errors += [ "Cap op failed: %s" % s ]
    for s in noent:
        if d.get (s.get_h ()):
            errors += [ "Cap op succeed but should have failed (%s)!" % s ]

    # Now let's see if we can grab the capabilities we asked for
    o_tmp = o_pre.clone ()
    for op in suc:
        if op.get_op () == flm.CAPABILITY_TAKE:
            o_tmp += op.get_h ()
    flo.set_label (flm.LABEL_O, o_tmp)
    
    # See if our O label was updated.
    o_post = flo.get_label (flm.LABEL_O)
    eq = (o_post == o_tmp)
    if not eq:
        errors += [ "PROBLEM! DIDN'T GET O EQUALITY AS I EXPECTED!" ]

    # Formulate an error message (perhaps)
    if len(errors):
        msg = "XXX %s XXX" % ("; ".join (errors))
    else:
        msg = "Everything OK! Yes!!"

    # The response should detail all of this stuff
    resp = "ops=%s; O_pre=%s; O_post=%s; eq=%d; %s" % \
        (str (out), str (o_pre), str (o_post), eq, msg)

    # Now output the response to the parent
    output (resp)

    # now we're all done!
    sys.exit (0)
    

main()
