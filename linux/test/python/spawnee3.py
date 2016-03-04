import os
import sys

#sys.stderr.write ("XXXX " + str(os.access ("/", 0)) + "\n")
#sys.stderr.write (repr(os.environ)  + "\n")

import flume.flmos as flmo
import flume as flm

print "hello; I am the child; pid=%x" % os.getpid ()
print "  - My label S=%s" % flmo.get_label (flm.LABEL_S)

sys.exit (2)
