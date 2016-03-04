

#
# test making tokens of different stripes
#

def clear_O ():
    print "clear O label"
    flmo.set_label (flm.LABEL_O)
    print "O label: " + str (flmo.get_label (flm.LABEL_O))

def newWidgets ():

    (h,c) = flmu.makeTag ("ep", "foo")
    cap = c[0]

    # make some notes to the console
    print "New tag: " + str (h)
    print "New capability: " + str (cap)
    print "Currrent O: " + str (flmo.get_label (flm.LABEL_O))

    return cap

def sleep (i):
    print "sleep %d seconds" % i
    time.sleep (i)

def req_privs (cap, tok):
    print "Requesting privs...."
    flmo.req_privs (cap, tok)
    print "O label: " + str (flmo.get_label (flm.LABEL_O))
    

import flume.flmos as flmo
import flume.util as flmu
import flume as flm
import time

cap = newWidgets ()

print "make login for 3 seconds"
tok = flmo.make_login (cap, 3, False)
print "Tok: " + tok
clear_O ()
req_privs (cap, tok)
clear_O ()

print "Trying a bad login"
try:
    flmo.req_privs (cap, "foo")
except flm.LoginError, e:
    print "Good, caught LoginException: " + str (e)

sleep (2)
req_privs (cap, tok)
clear_O ()

sleep (2)
req_privs (cap, tok)

sleep (4)
print "Requesting privs...."
try:
    req_privs (cap, tok)
except flm.ExpirationError , e:
    print "Good, caught expiration exception: " + str (e)

cap = newWidgets ()

print "make login for 3 seconds, fixed"
tok = flmo.make_login (cap, 3, True)
clear_O ()

sleep (1)
req_privs (cap, tok)
clear_O ()

sleep (3)
try:
   req_privs (cap, tok)
except flm.ExpirationError , e:
    print "Good, caught expiration exception: " + str (e)


