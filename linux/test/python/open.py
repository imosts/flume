"""
Tests for flmos.open()
"""

import flume
import flume.util as flumu
import flume.flmos as flmo

(etag, ecaps) = flumu.makeTag ('pe', 'e tag')

filels = flmo.LabelSet (S=flmo.Label ([etag]))

f = flmo.open ("/home/foo", 'cw', 0600, labelset=filels, endpoint=filels)
f.write("bla\n")
f.close ()

print "done"

