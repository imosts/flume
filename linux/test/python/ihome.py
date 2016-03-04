
import flume.flmos as flmo
import flume.util as flmu
import flume as flm
import os

t,c = flmu.makeTag ("ip", "foo")
flmo.set_label (flm.LABEL_I, flmo.Label ([t]))
os.stat ("/ihome")
