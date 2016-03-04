

import flume.flmos as flmo
import flume.util as flmu
import flume as flm
import os
import time

glbl = None

def do_raw (x, klass, s):
    global glbl

    raw = x.toRaw ()
    arm = raw.armor ()
    print "%s: armored: %s" % (s, arm)
    out = [ klass (raw),
            klass (flmo.RawData (dat = arm, armored = True)),
            ]

    if out[0] == out[1]:
        print "%s: OK! Armor/dearmor worked" % s
    else:
        print "%s: Shit! Armor/dearmor failed" % s

    if raw == glbl:
        print "WHOOPS! RawData equality is hosed!"
    glbl = raw
        
    for i,y in enumerate (out):
        if x == y:
            print "%s[%d]: OK!" % (s, i)
        else:
            print "%s[%d]: Whoops, not equal!!" % (s, i)
            print "  x=%s" % str (x)
            print "  y=%s" % str (y)

def do_labelset_raw ():
    S = flmo.Label ([ flmu.makeTag("ep", "foo-%d")[0] for d in range (5) ])
    I = flmo.Label ([ flmu.makeTag("ip", "foo-%d")[0] for d in range (4) ])
    O = flmo.Label ([ flmu.makeTag("wp", "foo-%d")[1][0] for d in range (3) ])
    ls = flmo.LabelSet ( S = S, I = I, O = O)
    do_raw (ls, flmo.LabelSet, 'LabelSet')

def do_label_raw ():
    l = flmo.Label ([ flmu.makeTag ("ep", "foo-A-%d")[0] for d in range (9) ])
    do_raw (l, flmo.Label, 'Label')

def do_handle_raw ():
    h,_ = flmu.makeTag ("ep", "foo-C")
    do_raw (h, flmo.Handle, 'Handle')

def main ():
    do_labelset_raw ()
    do_label_raw ()
    do_handle_raw ()

#print "sleep; %d" % os.getpid ()
#time.sleep (10)
main()    
