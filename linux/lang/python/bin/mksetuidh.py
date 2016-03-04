
#
# Make a read-protect tag, that only the Flume reference monitor
# can take back.
#

import flume.flmos as flmo
import flume.util as flmu
import flume as flm
import os.path
import time

(tag,caps) = flmu.makeTag (flags = "rp", name="flmsetuid")

print "# Handle generated %s" % time.ctime()
print "SetuidHandle %s" % tag.armor32()
