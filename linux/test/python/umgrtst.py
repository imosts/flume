
import flmw.umgrcli as ucli
from string import letters
from random import randint
import sys
import flume.flmos as flmo
import flume as flm
import os.path
import os


UNLEN = 6
PWLEN = 4

def generate (len):
    return ''.join ([ letters[randint (0,51)] for x in range (len)])

def print_labels (where = None):
    tab =  [ ("O", flm.LABEL_O),
             ("I", flm.LABEL_I),
             ("S", flm.LABEL_S) ]
    if where is not None:
        print where
    for p in tab:
        print " + %s = %s" % (p[0], str (flmo.get_label (p[1])))

cli = ucli.UmgrClient (sys.argv[1])

un = generate (UNLEN)
pw = generate (PWLEN)

print "New user; username='%s' and pw='%s'" % (un, pw)
uid1 = cli.makeUser (un, pw)
print "UserID returned: %s" % uid1

u = cli.loginUser (un, pw)
print "User object returned...."

if uid1 != u.userId ():
    raise ValueError, "Vaule Mismatch! UIDs not equal ('%s' v. '%s')" \
          % (uid1, u.userId ())

print_labels ('Label Check...')

# the following isn't explicitly necessary though maybe we should
# move in this direction.
#flmo.set_label (flm.LABEL_O, flmo.get_label (flm.LABEL_O) + u._w_tag )
S_orig = flmo.get_label (flm.LABEL_S)
flmo.set_label (flm.LABEL_S, flmo.Label ([ u._e_tag ]))

print_labels ('Readjust labels...')

pd = u.exportProtectDir ()
fn = os.path.sep.join ([pd, "birdie.txt"])
f = open (fn, "w")
f.write ("Tweet tweet.\n")
f.close ()

print ("Labels on new file (%s): %s" % (fn, str (flmo.stat_file (fn))))

f = open (fn, "r")
print "Read file..."
print  " " + f.readline ().strip ()

d = os.path.sep.join ([pd, "bigbird"])
os.mkdir (d)

print ("Labels on new dir (%s): %s " % (d, str (flmo.stat_file (d))))

# need to turn label back before we can talk to the usermanager
# again!!!
flmo.set_label (flm.LABEL_S, S_orig)

print_labels ('Labels reset...')

gn = generate (UNLEN)

print "Login user again...."
u = cli.loginUser (un, pw)
print "Login succeeded..."

print "New group: %s" % gn
gid = cli.newGroup (gn, un, pw)
print "GroupID returned: %s" % gid

un2 = generate (UNLEN)
pw2 = generate (PWLEN)

print "New user; username='%s' and pw='%s'" % (un2, pw2)
uid2 = cli.makeUser (un2, pw2)
print "UserID returned: %s" % uid2

print "Read groups file for user: %s" % un
out = cli.invite (gn, un, pw, un2)
print "String returned: %s" % out

print "Accepting all group invites for user: %s" % un2
cli.acceptAllGroupInvites (un2, pw2)
print "Accepted!"

del cli


