import os
import sys

#sys.stderr.write ("XXXX " + str(os.access ("/", 0)) + "\n")
#sys.stderr.write (repr(os.environ)  + "\n")

import flume.flmos as flmo
import flume as flm

#
# Set our label to whatever our parents told us to set it to.
#
flmo.set_label (flm.LABEL_S, flmo.Label ([ flmo.Handle (sys.argv[1])]) )

print "hello; I am the child; pid=%x" % os.getpid ()

sys.exit (3)
