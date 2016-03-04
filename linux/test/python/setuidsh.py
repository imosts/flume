
import flume.flmos as flmo
import flume
import sys
import os

stdin = flmo.wpipe ()
stdout = flmo.rpipe ()

argv = sys.argv[1:]
flmo.spawn (prog=argv[0], argv=argv, env=None, opt=flume.SPAWN_SETUID,
           claim = [stdin[1], stdout[1]])

inh = os.fdopen (stdin[0], "w", 1)
outh = os.fdopen (stdout[0], "r", 1)

go = True
while go:
    l = sys.stdin.readline ()
    if len (l) == 0:
        sys.stderr.write ("EOF from shell...\n")
        go = False
    else:
        inh.write (l)
        resp = outh.readline ()
        sys.stdout.write (resp)

inh.close ()
outh.close ()


(pid, status) = flmo.waitpid ()
print "Exit: %s,%d" % (str (pid), status)
