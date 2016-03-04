
#
# test making a directory in an integrity-rooted FS
#


import flume.flmos as flmo
import flume.util as flmu
import flume as flm
import os.path

def runtest (ls):

    print "labelset = %s" % ls
    fn = ls.to_filename ()
    print "filename = %s" % fn
    d = "/ihome/" + fn
    print "dir = " + d
    flmo.set_label (typ = flm.LABEL_I, label = ls.get_I())
    flmo.set_label (typ = flm.LABEL_S, label = ls.get_S())
    flmo.mkdir (path = d, labelset = ls, mode = 0755)
    if not (os.path.exists (d) and os.path.isdir (d)):
        raise ValueError, "directory %s should exist!" % d

    print "stat_file(%s) => %s" % (d, flmo.stat_file (d))

    fn = d + "/hello"
    f = flmo.open (name = fn, flags = "cw", labelset = ls, mode = 0644)
    f.write ("hello world!\n")
    f.close ()
    
    f = flmo.open (name = fn, flags = "r")
    print "Read from file: " + f.read ()[0:-1]
    f.close ()

(itag,icaps) = flmu.makeTag (flags = "ip", name="foo")
(stag,scaps) = flmu.makeTag (flags = "ep", name="foo")
S = flmo.Label ([stag])
I = flmo.Label ([itag])
ls = flmo.LabelSet ( S = S, I = I)

runtest (ls)

ls = flmo.LabelSet (I = I)

runtest (ls)

ls = flmo.LabelSet (S = S)

runtest (ls)


try:
    flmo.mkdir ("/ihome/foo", labelset = ls, mode = 0755)
except flm.PermissionError, e:
    print "Good, caught permission error: " + str (e)

try:
    flmo.open ("/ihome/bar", flags = "cw", labelset = ls, mode = 0644)
except flm.PermissionError, e:
    print "Good, caught permission error: " + str (e)

