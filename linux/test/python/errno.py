
"""errno.py

A small script to test errno handling in flume / python layer.
"""

import flume
import flume.flmos as flmo
import errno
import os

fn = "/tmp/xy1"

print "making file: " + fn
fh = flmo.open (name = fn, flags = "cw")
fh.write ("hello\n")
fh.close ()

print "attempting to mkdir: " + fn
try:
    flmo.mkdir (path=fn)
except OSError, e:
    print "Good, got OSError: " + str (e)
    print "Errcode should be EEXIST=%d" % errno.EEXIST

print "attempting to symlink: " + fn
try:
    flmo.symlink (newfile=fn, contents ="xxxx")
except OSError, e:
    print "Good, got OSError: " + str (e)
    print "Errcode should be EEXIST=%d" % errno.EEXIST

print "unlinking file: " + fn
os.unlink (fn)
