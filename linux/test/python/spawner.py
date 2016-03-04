
import sys
import os
import time
import flume.flmos as flmo
import flume as flm
import os.path

prefix = os.path.dirname (sys.argv[0])

(fd, h) = flmo.socketpair ()

argv =  [ sys.executable, prefix + "/spawnee.py", h.armor32 () ]

ch = flmo.spawn (prog=argv[0], argv=argv, confined=True)

print "spawn gave ch=" + str (ch)
fh = os.fdopen (fd, "r")
print "read from child: " +  fh.read ().strip ()

(pid, status, visible) = flmo.waitpid (ch)
print "wait returned: %s,%d,%d" % (str (pid), status, visible)

    
