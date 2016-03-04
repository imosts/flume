
import flume.flmos as flmo
import flmw
import flmw.usermgr
import sys
import os
import flume as flm

class CmdError (flmw.Error):
    pass

ERR_NULL = 100
ERR_NOENT = 101
ERR_CMD = 200
ERR_GEN = 300


class MgrShell:
    """A shell based system for making new users and loging users in."""

    def checkpointLabels (self):
        ls = flmo.get_labelset ()
        self._ckpt = ls

    def restoreLabels (self):
        ls = flmo.get_labelset ()
        cpd = self._ckpt.toDictEnumKeys ()

        #
        # Can't do O label...
        #
        for k in [ flm.LABEL_S, flm.LABEL_I ]:
            flmo.set_label (k, cpd[k])

    def userConstructor (self):
        return flmw.usermgr.UserMgr

    def __init__ (self, uid):
        self._tab = { "newuser"    : self.newUser,
                      "login"      : self.login,
                      "newgroup"   : self.newGroup,
                      "invite"     : self.invite,
                      "accept-all" : self.acceptAllGroupInvites }
        self._umgr = self.userConstructor () (umgrId=uid)
        self._umgr.readTags ()
        self._umgr.unpackOLabel ()

    def output (self, x):
        if x[len(x) - 1] != "\n":
            x += "\n"
        sys.stdout.write (x)
        sys.stdout.flush ()
    
    def error (self, rc, e):
        self.output (str(rc) + " " + e + "\n")

    def success (self, e):
        self.output ("0 " + str(e) + "\n")

    def run (self):

        # strip off our integrity since we'll have to talk to users
        # with lower integrity than us; it would be interesting
        # if we could set the FD label to {}, but it didn't
        # work and no time to investigate (-MK 3/1/07)
        for i in [0, 1]:
            flmo.set_fd_label (flm.LABEL_I, i)
            
        #sys.stderr.write ("running in MgrShell!\n")
        go = True
        while go:
            l = sys.stdin.readline ()
            if len (l) > 0:
                self.handleCommand (l.split ())
            else:
                #sys.stderr.write ("EOF on stdin\n")
                go = False

    def invite (self, args):
        """
        User1 is inviting user2 into group g

               invite <g> <username1> <password> <username2>

        """
        if len (args) != 4:
            raise CmdError, "Expect 4 arguments: <g> <u1> <pw> <u2>"
        
        r = self._umgr.doInvite (*tuple(args))
        self.success (r)

    def newUser (self, args):
        """Make a new user:

               newuser <username> <password>

        is the expected input type."""
        
        if len(args) != 2:
            raise CmdError, "Expect 2 arguments: <username> <password>"

        ret = self._umgr.makeUser (args[0], args[1])
        self.success (ret)


    def acceptAllGroupInvites (self, args):
        """
        Accept all group invitations for the given user:

             accept-all <username> <password>

        is the expected input type."""
        if len(args) != 2:
            raise CmdError, "Expect 2 arguments: <username> <password>"

        u, uid = self._umgr.checkCredentials (args[0], args[1])
        n = self._umgr.drop_I ( u.acceptAllGroupInvites )
        self.success (n)
        

    def newGroup (self, args):
        """
        Make a new group, administrated by the given user:

              newgroup <groupname> <username> <password>

        where 'password' is the password for the given user.
        """
        
        if len (args) != 3:
            raise CmdError, "Expect 3 arguments : " \
                  + "<groupname> <username> <password>"

        u, uid = self._umgr.checkCredentials (args[1], args[2])
        g = self._umgr.makeUserGroup (args[0], u)
        self.success (g)
        

    def login (self, args):
        """Make a new login:

               login <username> <password>

        is the expected input type."""
        if len (args) != 2:
            raise CmdError, "Expect 2 arguments: <username> <password>"
        ret = self._umgr.makeLoginSession (args[0], args[1])
        s = '(' + ','.join(ret) + ')'
        self.success (s)

    def handleCommand (self, args):
        try:
            f = self._tab[args[0]]
        except IndexError, e:
            self.error (ERR_NULL, "No command given")
            return
        except KeyError, e:
            self.error (ERR_NOENT, "Command not found: " + str (e))
            return

        self.checkpointLabels ()
        
        try:
            # Actually run the chosen command, via function pointer call.
            f (args[1:])
        except CmdError, e:
            self.error (ERR_CMD, "%s error: %s" % (args[0], str (e)))
        except flmw.Error, e:
            self.error (ERR_GEN, "%s error: %s" % (args[0], str (e)))
            
        self.restoreLabels()

def usage ():
    print "usage: " + sys.argv[0] + " <user-mgr-uid>"
    sys.exit (1)

if len (sys.argv) != 2:
    usage ()

S = flmo.get_label (flm.LABEL_S)
if len (S) > 0:
    raise flm.PermissionError, \
          "need empty S label to run umgr, as opposed to %s" % S

sh = MgrShell (sys.argv[1])
sh.run()
