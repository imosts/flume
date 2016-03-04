
#
# A simple script to test file and EP configuration, with most code
# stolen from writefile.py
#

import flume.flmos as flmo
import flume.util as flmu
import flume as flm


t, c = flmu.makeTag ("ep", "foo")
f = "/home/xx." + t.armor32 ()
print "File => %s" % f
data = "Hello dog.\n"
S_lab = flmo.Label ( [ t ] )
ls = flmo.LabelSet ( S = S_lab)
print "LabelSet => %s" % ls

flmo.writefile (name = f, data = data, labelset = ls)

try:
    fh = open (f, "r")
except IOError, e:
    print "Good, caught OS error: %s" % e

fh = flmo.open (name = f, flags = "r", endpoint = ls)
print "Readfile %s: %s" % (f, fh.readlines ())

