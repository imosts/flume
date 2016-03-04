
import flume.flmos as flmos
import flume
import sys

h = flmos.new_handle (flume.HANDLE_OPT_DEFAULT_ADD, "Alice")
flmos.set_label (flume.LABEL_O, flmos.Label ())
f = open ("/tmp/alice.dat", "w")
flmos.set_label (flume.LABEL_S, flmos.Label ([h]) )

# Shouldn't get here
sys.stderr.write ("ok finished: %s\n" % flmos.get_label (flume.LABEL_S) )
