
import flume.flmos as flmo
import flume
import flume.util as flmu

(t,_) = flmu.makeTag ("pe", "foo")
i = flmo.Label ([t])
print "input => " + str (i)

for j in range (3):
    f = i.freeze ()
    print "frozen => " + str (f)
    l = f.thaw ()
    print "output => " + str (l)
