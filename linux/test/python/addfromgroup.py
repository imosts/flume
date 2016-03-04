"""
addfromgroup.py

A very contrived little tester.  Given a frozen tag, and a token,
and a capability, try to add the capability to our ownership label.
"""

import sys
import flume.flmos as flmos
import flume

def usage():
    sys.stderr.write ('usage: %s <tag> <token> <capability>' % sys.argv[0])
    sys.exit (2)

if len(sys.argv) != 4:
    usage()

tag = flmos.Handle (sys.argv[1])
token = sys.argv[2]
cap = flmos.Handle (long(sys.argv[3], 16))

flmos.req_privs (tag, token)
O = flmos.get_label (flume.LABEL_O)
print "Start out at O label: %s" % str (O)
O += [ cap ]
print "Attempt to set label to: %s" % str (O)
flmos.set_label (flume.LABEL_O, O)
print "Result: %s" % str (flmos.get_label (flume.LABEL_O))
