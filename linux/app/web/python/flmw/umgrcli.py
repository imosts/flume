
import flume.flmos as flmo
import flume
import sys
import os
import re
import flmw
import flmw.user as flmwu

class UmgrError (flmw.Error):
    pass

def parse (x):
    return tuple (x.strip ('()').split (','))


class UmgrClient:

    cmd_rxx = re.compile ("(?P<rc>\d+)(\s+(?P<data>.*))?")
  
    def __init__ (self, uid):

        hm = os.path.sep.join ([ "", flmw.IHOME, uid ])
        prog = os.path.sep.join ([ hm, flmw.UMGR_SBIN, "umgr.py.suwrp"])
        ls = flmo.stat_file (hm)
        argv = [prog]

        stdin = flmo.wpipe ("stdin")
        stdout = flmo.rpipe ("stdout")
        
        self._out_to_umgr = None
        self._in_from_umgr = None

        flmo.spawn (prog=argv[0], argv=argv, env=None, opt=flume.SPAWN_SETUID,
                   claim = [stdin[1], stdout[1]], I_min = ls.get_I ())

        self._out_to_umgr = os.fdopen (stdin[0], "w", 1)
        self._in_from_umgr = os.fdopen (stdout[0], "r", 1)


    def cmdp (self, *args):
        return parse (self.cmd (*args))
        
    def cmd (self, *args):
        """
        Issue command 'c' to the user manager.
        """
        c = " ".join (list (args)) + "\n"
        self._out_to_umgr.write (c)
        self._out_to_umgr.flush ()
        
        line = self._in_from_umgr.readline ()
        if line is None:
            raise UmgrError, "EOF encountered"
        
        m = self.cmd_rxx.match (line)
        
        if m is None:
            raise UmgrError, "Unexpected output: %s" % (line)

        rc = m.group ("rc")
        data = m.group ("data")

        try:
            if int(rc) != 0:
               raise UmgrError, "Non-OK result code: %d" % int(rc)
        except ValueError:
            raise UmgrError, "Non-integer return code: %s" % rc

        return data

    def makeUser (self, un, pw):
        """
        Make a user with the given username and password.
        Return a new userid of the form X..Y
        """
        return self.cmd ("newuser", un, pw)

    def invite (self, grp, un, pw, u2):
        """
        Login user with username and PW, and invite user u2 into
        group 'grp'
        """
        return self.cmd ("invite", grp, un, pw, u2)

    def getSession (self, un, pw):
        """
        Login the user with the given username and password.
        Return a triple of the form (UID,GroupToken,SessionPW)
        """
        return self.cmdp ("login", un, pw)

    def newGroup (self, gname, un, pw):
        """
        Given a username and a password, make a new group administrated
        by that user.
        """
        return self.cmd ("newgroup", gname, un, pw)

    def acceptAllGroupInvites (self, un, pw):
        """
        Given a username and a password, accept all group invitations for
        the given user.
        """
        return self.cmd ("accept-all", un, pw)
        

    def loginUser (self, un, pw):
        """
        Given a username and password, do a FLUME login and return a
        user object reprenting the user.
        """
        uid,h,spw = self.getSession (un, pw)
        flmo.req_privs (flmo.Handle (h), spw)
        u = flmwu.User (uid=uid)
        u.readTags ()
        return u

    def disconnect (self):
        if self._in_from_umgr:
            self._in_from_umgr.close ()
            self._in_from_umgr = None
        if self._out_to_umgr:
            self._out_to_umgr.close ()
            self._out_to_umgr = None

    def __del__ (self):
        self.disconnect ()

