import os
import sys

##
## XXX important! XXX
##
##   this only works if debug mode is turned on; (should probably catch
##   the exception...)
##
#sys.stderr.write ("XXXX " + str(os.access ("/", 0)) + "\n")
#sys.stderr.write (repr(os.environ)  + "\n")

import flume.flmos as flmo
import flume as flm

fd = flmo.claim (sys.argv[1])
fh = os.fdopen (fd, "w")
fh.write ("hello; I am the child; pid=%x\n" % os.getpid ());
fh.close ()
