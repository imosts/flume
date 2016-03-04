
#
# make a little setuid wrap script
#

import flume.flmos as flmo
import flume.setuid as flms
import flume as flm
import flume.util as flmu

(t,c) = flmu.makeTag ("ip", "test setuid wrapper")
cap = c[0]
tok = flm.random_str (20)
flmo.make_login (cap, tok)

prog = "/disk/max/run/pybin/printo.py"
src = open (name = prog, mode = "r")
lines = []
for l in src:
    lines += [ l ]

I = flmo.Label ([t]) 
flmo.set_label (flm.LABEL_I, I)
ls = flmo.LabelSet (I = I)
d = "/ihome/" + I.freeze ().armor32 ()
flmo.mkdir (d, labelset = ls)
p = d + "/printo.py"

f = flmo.open (name = p, flags = "cw", labelset = ls)
for l in lines:
    f.write (l)
f.close ()

# need to set our I label low again so we can write out to a
# dirty directory like /home
flmo.set_label (flm.LABEL_I)

flms.makeWrapper (dest="/home/tst",
                 argv = [ "/usr/local/bin/python", p ],
                 tag = cap,
                 token = tok,
                 ilabel = I)

                 
