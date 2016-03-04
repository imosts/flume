
import sys
import os
import flume.flmos as flmo
import flume as flm
import os.path

prefix = os.path.dirname (sys.argv[0])
argv =  [ sys.executable, prefix + "/closedfiles_child.py" ]

ch = flmo.spawn (prog=argv[0], argv=argv, confined=True)

(pid, status) = flmo.waitpid ()
print "wait returned: %s,%d" % (str (pid), status)
