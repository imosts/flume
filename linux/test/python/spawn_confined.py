
import sys
import os
import flume.flmos as flmo
import flume as flm
import os.path

(fd0, stdin) = flmo.socketpair ()
(fd1, stdout) = flmo.socketpair ()
(fd2, stderr) = flmo.socketpair ()
argv = sys.argv[1:]

ch = flmo.spawn (prog=argv[0], argv=argv, confined=True, claim=[stdin, stdout, stderr])
print "--- spawn gave ch=" + str (ch) + '---'

fin = os.fdopen (fd0, "w")
fout = os.fdopen (fd1, "r")
ferr = os.fdopen (fd2, "r")

sys.stdout.write (fout.read ())
sys.stderr.write (ferr.read ())

(pid, status, visible) = flmo.waitpid ()
print "--- wait returned: pid %s, status %d, visible %s ---" % (str (pid), status, visible)

