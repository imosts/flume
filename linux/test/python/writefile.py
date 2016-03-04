
import flume.flmos as flmo
import flume.util as flmu
import flume as flm

t, c = flmu.makeTag ("ep", "foo")
f = "/home/xx." + t.armor32 ()
print "File => %s" % f
data = "Hello dog.\n"
ls = flmo.LabelSet ( S = flmo.Label ( [ t ] ))
print "LabelSet => %s" % ls

flmo.writefile (name = f, data = data, labelset = ls)

try:
    fh = open (f, "r")
except IOError, e:
    print "Good, caught OS error: %s" % e

flmo.set_label (flm.LABEL_S, flmo.Label ([ t ] ))
fh = open (f, "r")
print "Readfile %s: %s" % (f, fh.readlines ())




