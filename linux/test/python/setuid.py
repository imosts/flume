
import flume.flmos as flmo
import flume
import sys

argv = sys.argv[1:]
flmo.spawn (prog=argv[0], argv=argv, env=None, opt=flume.SPAWN_SETUID)
(pid, status) = flmo.waitpid ()
print "Exit: %s,%d" % (str (pid), status)
