import os
import sys
import flume
import flume.flmos as flmo

def out (s):
    sys.stderr.write ('XXX ' + s + '\n')


out ('In closedfiles_child')
h = flmo.new_handle (flume.HANDLE_OPT_DEFAULT_SUBTRACT | flume.HANDLE_OPT_PERSISTENT, "ihandle")
out ('New handle is %s' % str(h))

l = flmo.Label ([h])
ls = flmo.LabelSet (I=l)

flmo.set_label (flume.LABEL_I, l)

# Make the ihome directory
d = os.path.join ('/ihome/', ls.to_filename ())
out ('Creating directory %s' % d)
flmo.mkdir (d, labelset=ls)

# Create the file
f = os.path.join (d, 'testfile1')
out ('Creating file %s' % f)
f = flmo.open (f, 'cw', mode=664, labelset=ls)

# Close the file
f.write ('hello\n')
f.close ()

flmo.closed_files ()

# Drop the I tag
flmo.set_label (flume.LABEL_I, flmo.Label ())
out ('Dropped h from I label')

flmo.set_label (flume.LABEL_O, flmo.Label ())
out ('Dropped h from O label')
