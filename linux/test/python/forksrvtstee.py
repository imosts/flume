
import flume.flmos as flmo
import flume.frksrv as frk
import sys
import os

#sys.stderr.write ("Fork Serve Testee: Starting up!\n")

def usage ():
    sys.stderr.write ("usage: %s <pipe-token>\n" % sys.argv[0])
    sys.exit (2)

class Child (frk.Child):
    def serve (self, args):
        sys.stdout.write ("OK, I'm here! LabelSet=%s, args=%s" % (flmo.get_labelset (), args))
        return 0

def main ():
    if len (sys.argv) != 2:
        usage ()
    srv = frk.ForkServer (Child)
    srv.start (sys.argv[1])

main ()
