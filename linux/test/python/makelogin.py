
import flume.flmos as flmo
import flume.util as flmu
import flume
import sys

(h,c) = flmu.makeTag ("ep", "foo")

l = flmo.get_label (flume.LABEL_O)
print "O label: " + str (l)

tok = flmo.make_login (c[0])

print "New tok: " + tok

flmo.set_label (flume.LABEL_O)
print "Clear O label"

l = flmo.get_label (flume.LABEL_O)
print "O label: " + str (l)

flmo.req_privs (c[0], tok)
print "Refetch priv: " + str (c[0])

l = flmo.get_label (flume.LABEL_O)
print "O label: " + str (l)

flmo.set_label (flume.LABEL_O)
print "Clear O label"

l = flmo.get_label (flume.LABEL_O)
print "O label: " + str (l)

try:
    flmo.req_privs (c[0], tok + "foo")
except flume.LoginError, e:
    print "Good, got login error: " + str (e)
