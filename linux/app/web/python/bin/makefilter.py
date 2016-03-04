
# 1) Make two tags (moin, adobe)
# 2) Make a filter find = {moin}, repl = {moin, adobe}

import flume.flmos as flmo
import flume.setuid as flms
import flume.util as flmu
import flume as flm
import sys

def newtag (s, tag_desc):
    tag, caps = flmu.makeTag ("ip", tag_desc)
    tok = flmo.make_login (caps[0])
    l = flmo.Label ([tag])
    frozen = l.freeze ()

    # Output is <s> frozen,i_label, armored,frozen,i_label, armored,i_tag, armored_password
    print "%s 0x%x %s 0x%x %s %s" % (s, frozen.val (), frozen.armor32 (),
                                     tag.val (), tag.armor32 (), tok)
    return l, caps

def usage ():
    print "makefilter.py {find_desc| -f frozen_find_lab} repl_desc"
    sys.exit (1)
    
# deal with frozen find labels
if (sys.argv[1] == "-f"):
    finds, repls = sys.argv[2:4]
    h = flmo.Handle ()
    h.dearmor32 (finds)
    find = h.thaw ()
else:
    finds, repls = sys.argv[1:3]
    find, findcaps = newtag ("find_lab", sys.argv[1])

repl, replcaps = newtag ("new_integrity", sys.argv[2])
repl += find.toList ()

# Filename is filter.x.y where x and y are armored, frozen, labels
fn = "/home/filter.%s.%s" % (find.freeze ().armor32 (), repl.freeze ().armor32 ())

# Adobe trusts Moin
flms.makeFilter (name = fn,
                find = find,
                replace = repl,
                caps = replcaps)
print "filter %s" % fn
print "maps find %s replace %s" % (find, repl)
