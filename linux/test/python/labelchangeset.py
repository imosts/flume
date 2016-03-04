
import flume.flmos as flo
import flume.util  as flu

n = 10
s = 4

tags = [ flu.makeTag ( flags ="e", name = "h%d" %i )[0] for i in range(n) ]

print "New tags: %s" %  str ([ str(t) for t in tags ])

lcsr = [ flo.LabelChange ( flo.Label (tags[i:i+s]) ) for i in range (n-s) ]

print "New label changes: %s" % str ([ str (lc) for lc in lcsr ])

lcs = flo.LabelChangeSet (lcsr)

print "Label change set: %s" % str (lcs)
print "Label change set[1:3]: %s" % str ([ str (x) for x in lcs[1:3]])

del (lcs[0:2])
print "Label change set: %s" % str (lcs)
lcs[1] = lcs[2]
print "Label change set: %s" % str (lcs)

