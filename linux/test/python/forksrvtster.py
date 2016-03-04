
import sys
import os
import flume.flmos as flmo
import flume as flm
import flume.util as flu
import os.path
import flume.frksrv as frk

prefix = os.path.dirname (sys.argv[0])
path = prefix + '/forksrvtstee.py'

srv = frk.ForkServerIface ()
srv.launch (path)

for i in range (10):
    t,_ = flu.makeTag ("ep", "foo-tag-%d" % i)
    l = flmo.Label ( [ t ] )
    ls = flmo.LabelSet (S=l)
    print "%d: new label: %s" % (i, str (l))

    fin, fout, ferr = srv.call (ls=ls, args=["foo", "bar"])
    print "Received from child stdout: " + fout.readline ().strip ()
    print "Received from child stderr: " + ferr.readline ().strip ()
    
srv.shutdown ()
