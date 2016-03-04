#
# A little test script to test basic flume features in python
#
import flume 
import flume.flmos as flmo

# make handle opts
opts = flume.HANDLE_OPT_PERSISTENT | flume.HANDLE_OPT_DEFAULT_ADD

# make a new handle
h1 = flmo.new_handle (opts, "h1")

# make a nice display
print "New handle: " + str (h1)

# get our S label
S = flmo.get_label (flume.LABEL_S)

print "Existing label: " + str(S)

# load the S label with our new handle
S += h1

print "New label: " + str(S)

# now reset the S label; will raise an error if failed
flmo.set_label (S, flume.LABEL_S)

# now reload the S label
S2 = flmo.get_label (flume.LABEL_S)

print "Regot label: " + str (S2)

# Test armor32 of handles
print "Armor32(h1) = " + h1.armor32 ()

# Test freezing a label
print "frozen (new label) = " + S2.freeze ().armor32 ()
