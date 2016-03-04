
import flume.flmos as flmo
import flume.setuid as flms
import flume.util as flmu
import flume as flm

i = [ flmu.makeTag ("ip", "foo%d" % i )[0] for i in range (2) ]

print "Made handles: %s" % '; '.join ([str (x) for x in i ])

f = "/home/filter.%s" % '.'.join ([x.armor32 () for x in i ])

print "New filter: %s" % f

find = flmo.Label (i[0:1])
replace = flmo.Label (i)
caps = [ i[1].toCapability (flm.CAPABILITY_ADD) ]

findcap = i[0].toCapability (flm.CAPABILITY_ADD)
replcap = i[1].toCapability (flm.CAPABILITY_ADD)

tok = flmo.make_login (findcap)
print "Login for %s is %s" % (findcap, tok)
tok = flmo.make_login (replcap)
print "Login for %s is %s" % (replcap, tok)


flms.makeFilter (name = f, find = find, replace = replace, caps = caps)

findls = flmo.LabelSet (I = find)
data = "High integrity data: %s" % findls

flmo.set_label (flm.LABEL_I, find)
name = "/ihome/" + findls.to_filename ()
flmo.mkdir (path = name, labelset = findls)
newfile = name + "/newfile"

print "New file: %s" % newfile

flmo.writefile (name = newfile, labelset = findls, data = data)

flmo.set_label (flm.LABEL_I)
flmo.apply_filter (name = f, typ = flm.LABEL_I)

newlab = flmo.Label (i[1:2])
flmo.set_label (flm.LABEL_I, newlab)
o = open (newfile, "r")

print "Read Data: %s" % o.readlines ()




