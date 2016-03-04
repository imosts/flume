
"""
groups.py

A little script to test that group walking works as we would expect,
especially with the caching layer turned on.
"""

import flume.util as flmu
import flume.flmos as flmo
import flume as flm

def test_inclusion (cap, group, expected):
    lhs = flmo.Label ( [cap ] )
    rhs = flmo.Label ( [ group.toCapability (flm.CAPABILITY_GROUP_SELECT)] )

    res = lhs.subsetOf ( [ rhs ] , flm.COMPARE_NONE )
    notstr =""
    if res is False:
        notstr = "not "
    tst = "%s %sin {%s}" % (cap, notstr, group )

    judgment = "Good"
    if res != expected:
        judgment = "BAD"

    print "%s: %s" % (judgment, tst)

#
# Create 3 capabilities c0, c1, and c2
#
c = []
for i in range (3):
    t, caps = flmu.makeTag (flags = "wp", name = "c%d" % i)
    c += caps

#
# Create a new group, G = ( c0, c1 )
#
G = flmo.new_group ("G", None)
flmo.add_to_group (G, flmo.Label ( c[0:2] ) )
    
#
# Create a new group, H = ( G, c2 )
H = flmo.new_group ("H", None)
l = flmo.Label ([ c[2], G.toCapability (flm.CAPABILITY_GROUP_SELECT) ] )
flmo.add_to_group (H, l)

for j in range (2):
    test_inclusion (c[0], G, True)

for j in range (2):
    test_inclusion (c[0], H, True)

for j in range (2):
    test_inclusion (c[2], G, False)

flmo.add_to_group (G, flmo.Label ([c[2]]))

for j in range (2):
    test_inclusion (c[2], G, True)

for j in range (2):
    test_inclusion (c[0], H, True)

