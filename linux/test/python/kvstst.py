import sys, os, socket, flmkvs, flmkvs.client
import flume.flmos as flmo

def usage ():
    print '%s [sockfile]' % sys.argv[0]
    sys.exit (1)

sockfile = flmkvs.default_sockfile
if len (sys.argv) > 2:
    sockfile = sys.argv[2]


kvs = flmkvs.client.kvsconnection ()

r = kvs.put ("bla", "foo bar", flmo.LabelSet ())
print "put returns %s" % r

r = kvs.get ("bla")
if r != "foo bar":
    raise AssertionError, 'get 1 failed'

r = kvs.remove ("bla")
print "remove returns %s" % r
            

print "PASS"

# Print list of available methods
#print s.system.listMethods()

