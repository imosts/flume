import flume
import flume.flmos as flmo
import flume.util
import sys

def dbg (s):
    if False:
        sys.stderr.write ('%s\n' % s)
    
def check_data (fn, data, s):
    f = open (fn, 'r')
    if f.read () != data:
        print "FAIL: incorrect file contents pass %s" % s
    else:
        print "PASS: correct file contents pass %s" % s

def create_wp_file (data):
    # Create a write protected file
    t, c = flume.util.makeTag ('wp', 'writeprotect')
    dbg ("  my labelset: %s" % flmo.get_labelset ())

    fn = '/home/xx.' + t.armor32 ()
    dbg ('  filename = %s' % fn)
    ls = flmo.LabelSet (O=flmo.Label ([t]))

    f = flmo.open (fn, 'cw', 0644, ls)
    f.write (data)
    f.close ()

    return (fn, t)

def test_writeprotect ():
    # Test for proper O label semantics
    flmo.set_label (flume.LABEL_S);
    data = "write protected data\n"

    fn, stag = create_wp_file (data)
    check_data (fn, data, '1')

    try:
        flmo.set_label (flume.LABEL_O);
        dbg ("  my labelset: %s" % flmo.get_labelset ())
        
        f = open (fn, 'wt')
        f.write (data + "New data\n")
        f.close ()
        print "FAIL: file should be unreadable 1"
    except IOError, e:
        print "PASS: file should be unreadable 1"

    check_data (fn, data, '2')

    fn, stag = create_wp_file (data)
    check_data (fn, data, '3')

    try:
        flmo.set_label (flume.LABEL_O);
        dbg ("  my labelset: %s" % flmo.get_labelset ())
        
        f = open (fn, 'wt')
        f.write (data + "New data2\n")
        f.close ()
        print "FAIL: file should be unreadable 2"
    except IOError, e:
        print "PASS: file should be unreadable 2"

    check_data (fn, data, '4')


if len (sys.argv) == 2:
    fn = sys.argv[1]
else:
    print "usage: " + sys.argv[0] + " <file>"
    sys.exit (1)

(h, _) = flume.util.makeTag ("pe", "test handle")

print "New handle => " + str (h)
s = flmo.Label ([h])
print "New Label => " + str (s)
ls = flmo.LabelSet ( { "S" : s } )
print "New LabelSet => " + str (ls)

f = flmo.open (fn, "cw", 0644, ls)

flmo.set_label (flume.LABEL_S, s);

f.write ("foobar!\n")
f.write ("byenow!\n")

try:
	f.close ()
except Exception, e:
	print "Close failed: " + str (e)

ls = flmo.stat_file (fn)
print "file('%s') => %s" % (fn, str (ls))

f = flmo.open (fn, "r", 0, ls)

print "Line1 => " + f.readline ()

test_writeprotect ()
