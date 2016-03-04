
import flume.flmos as flmo
import sys

for f in sys.argv[1:] :
    ls = flmo.stat_file (f)
    print "%s => %s" % (f, ls)

