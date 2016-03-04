import sys, flume, os.path
import flume.flmos as flmo
from wikicode.util import helper_write, helper_read

if not os.path.exists ('/ihome/0'):
    flmo.mkdir ('/ihome/0')

for i in range (1000):
    fn = os.path.join ('/ihome/0/', flume.random_str (4))
    dat = flume.random_str (40)
    helper_write (fn, dat)
    dat2 = helper_read (fn)
    flmo.unlink (fn)

    if dat == dat2:
        print "Success: %s == %s" % (dat, dat2)
    else:
        print "Failure: %s != %s" % (dat, dat2)

    
