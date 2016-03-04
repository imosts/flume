"""flmw.usermgr

Libraries for the UserMgr users on a Flume web syste.
"""

import flume as flm
import flume.flmos as flmo
import flume.util as flmu
import flume.setuid as flms
import os.path
import re
import flmw
import flmw.user as flmwu
import flmw.group as flmwg
import flmw.principal as flmwp
import flmw.util
import sys

class UserMgr:

    def __init__ (self, umgrId=None, ppl=None, debug = False):
        self._debug = debug
        if umgrId is not None and ppl is None:
            ppl = UserMgrPrincipal (uid=umgrId)
            
        self._princ = ppl
        self._I_runas_set = False

    def get_I_runas (self):
        if not self._I_runas_set:
            self._I_runas = flmo.get_label (flm.LABEL_I)
        return self._I_runas

    def drop_I (self, fn):
        I = self.get_I_runas ()
        flmo.set_label (flm.LABEL_I)
        r = fn ()
        flmo.set_label (flm.LABEL_I, I)
        return r

    def unpackOLabel (self):
        """Unpack our O label a bit, and retrieve c+(i_tag) from the
        group and add it into our O.  We might get into a position
        in which we need to switch from I=[i_tag,foo] back to I=[i_tag]
        and we won't be able to search our group then."""
        O = flmo.get_label (flm.LABEL_O)
        O += [ self._princ._i_tag.toCapability (flm.CAPABILITY_ADD) ]
        flmo.set_label (flm.LABEL_O, O)

    def readTags (self):
        self._princ.readTags ()

    def homeDir (self):
        return self._princ.homeDir ()

    def userExists (self, uname):
        lnk = flmw.util.usernameToSymlink (uname, self.directoryDir())
        try:
            os.readlink (lnk)
        except OSError:
            return False
        return True

    def userConstructor (self):
        return flmwu.User

    def makeUser (self, uname, pw):
        u = self.userConstructor () (uname=uname, umgr=self._princ)
        return self.makePrincipal (u, pw)

    def makeUserGroup (self, gname, admin):
        g = flmwg.UserGroup (gname=gname, umgr=self._princ)
        gid = self.makePrincipal (g, None)

        # need to set our integrity up to the admin's integrity
        # in order to write to the capability group on his
        # behalf.
        admin.addSelfToUserGroup (g, flmwg.ADMIN )

        return gid

    def makePrincipal (self, u, pw):
        u.makeTags ()
        uname = u._username
        
        if self._debug:
            sys.stderr.write ("UserMgr.makeUser(%s): new I tag: %s\n"
                              % (uname, str (tc)))

        hd = u.homeDir ()

        # make the user symlink with the integrity of the user manager
        self._princ.setIntegrity ()
        try:
            self.makeUserSymlink (uname=uname, hdir=hd)
        except OSError, e:
            flmo.set_label (flm.LABEL_I) # clear I label on way out
            sys.stderr.write ("UserMgr.makeUser(%s): symlink error: %s\n"
                              % (uname, str (e)))
            raise flmw.UserExistsError, "username exists: '%s'" % uname
        
        # set our integrity level to that of the User
        u.setIntegrity ()

        # now we make the homedir (after making the symlink)
        try:
            u.makeHomeDir ()
        except Exception, e:
            flmo.set_label (flm.LABEL_I) # clear I label on way out
            self.killUserSymlink (uname=uname)
            raise e

        # now make the user, allocating tags, groups, and login
        # token, then writing all out to a tags file in the
        # user's homedir
        u.make (pw)

        # we want to change our integrity back to normal for the umgr;
        # this means we have to explicitly set our I label to [], and then
        # set to I=[i].  If not for the first step, then we wouldn't be
        # able to read some of the groups in our ownership label.
        flmo.set_label (flm.LABEL_I)
        self._princ.setIntegrity ()

        # Grant one of the new capabilities to the usermanager, so the
        # usermanager can declassify the ".tags" file on future
        # login attempts
        flmo.add_to_group (self._princ.userGroup (), u.userMgrCaps () )

        # Once again, clear our integrity label...
        flmo.set_label (flm.LABEL_I)

        return u.userId ()

    def doInvite (self, g, admin_un, pw, u2_un):
        ret = self.drop_I (lambda : self._doInvite (g, admin_un, pw, u2_un))
        return ret

    def _doInvite (self, g, admin_un, pw, u2_un):
        """
        Invite user u into group g, under admin's authority.
        """
        admin,_ = self.checkCredentials (admin_un, pw)
        admin.readGroupsFile ()
        try:
            g_triple = admin._user_groups[g]
            gh = flmo.Handle (g_triple[1])
            privs = g_triple[2]
            grp = g_triple[0]
        except KeyError:
            raise flmw.GroupNotFound, \
                  "Group '%s' not found in %'s groups file" % (g, admin_un)
        
        u2,uid2 = self.findUser (u2_un)
        tok = flmo.make_login (h = gh, duration = 60*60*24, fixed = True)
        u2.appendToInvitesFile (grp._username, grp._uid, gh, tok,
                                privs, admin_un)
        return str (uid2)
        

    def makeLoginSession (self, uname, pw):
        u, uid = self.checkCredentials (uname, pw)
        spw = flmo.make_login (h = u.groupCap (), duration = 3600,
                              fixed = False)
        return (uid, u.groupCap().armor32(), spw)

    def checkCredentials (self, uname, pw):
        u, uid = self.findUser (uname)
        self.drop_I (lambda : u.login (pw))
        return (u, uid)

    def findUser (self, uname):
        d = flmw.util.usernameToSymlink (uname, self.directoryDir())
        
        try:
            targ = os.readlink (d)
        except OSError, e:
            sys.stderr.write ("Link '%s' not found" % d)
            raise flmw.UserNotFoundError, "User not found: %s" % uname
        
        try:
            uid = flmw.util.home2uid (targ)
        except IndexError, e:
            sys.stderr.write ("Cannot parse link '%s': %s" % (targ, e))
            raise flmw.UserMgrError, "Bad symlink for user: %s" %targ
        
        u = self.userConstructor () (uid = uid, umgr = self._princ)
        self.drop_I (lambda : u.readFiles ())
        return (u, uid)
    
    def lookupUser (self, uname):
        pass

    def directoryDir (self):
        d = os.path.sep.join ([ self.homeDir () , flmw.UMGR_DIR ])
        return d

    def makeParentDirs (self, lnk):
        ls = self._princ.publicDirLabelSet ()
        flmu.mkdirAll (path = lnk, labelset = ls, stopat = -1)

    def makeUserSymlink (self, uname, hdir):
        lnk = flmw.util.usernameToSymlink (uname, self.directoryDir())
        self.makeParentDirs (lnk)
        os.symlink (hdir, lnk)

    def killUserSymlink (self, uname):
        os.unlink (flmw.util.usernameToSymlink (uname, self.directoryDir()))

    def prog_name (self):
        return 'umgr.py'

    def initPrincipal (self, bytes=20):
        """
        Call this to create a new user manager, including its homedir
        and setlabel wrapper script.
        """
        u = UserMgrPrincipal ()
        u.makeTags ()

        u.setIntegrity ()
        hdir = u.makeHomeDir ()
        u.make ()

        # The directory manager has 3 additional subdirs in his homedir:
        #
        #  dir/  - Where it's storing a directory mapping of each user
        #  bin/  - Where it's storing its login scripts
        #  setuid/ - Where it's storing its setuid wrappers.
        #
        dirs = {}
        pdls = u.publicDirLabelSet()
        for d in [ ("dir", flmw.UMGR_DIR),
                   ("setuid", flmw.UMGR_SBIN),
                   ("bin", flmw.UMGR_BIN) ] :
            path = os.path.sep.join ([hdir, d[1]])
            dirs[d[0]] = path
            flmo.mkdir (path=path, labelset = pdls)

        # Use UserMgr.prog_name because all clients look for "umgr.py.suwrp" 
        dest = os.path.sep.join ([dirs["setuid"], UserMgr.prog_name (self)])

        bindir = os.path.dirname (sys.argv[0])
        argv = [ sys.executable,
                 os.path.sep.join ([bindir, self.prog_name ()]),
                 u.userId() ]
        flms.makeWrapper (dest=dest, argv=argv, tag=u.groupCap(),
                          token=u.loginToken (), labelset = pdls,
                          ilabel = pdls.get_I())
        
        # return the tag so that we can start up a usermanager again...
        return (u.loginToken (), u.groupTag (), hdir, u.userId() )


UMGR_NAME = "UserMgr"

class UserMgrPrincipal (flmwp.Principal):
    """The principal who is the 'user manager' for the rest of the
    system; somewhat like other users, but doesn't have GroupManager
    export protect tag, and instead has a GroupManager Export-Protect
    group for storing everyone else's declassification privileges."""
        
    def userGroup (self):
        return self._g_umgr_tag

    def _makeAttrMap (self):
        flmwp.Principal._makeAttrMap (self)
        self._attr_map["UmgrExportGroup"] = ("_g_umgr_tag", None)
        
    def __init__ (self, uid=None):
        flmwp.Principal.__init__ (self, uname=UMGR_NAME, uid=uid, umgr=None)

    def publicDirLabelSet (self):
        """Labelset used for writing out to public directories."""
        ls = flmo.LabelSet ( I = self.integrityLabel (),
                            O = flmo.Label ([ self.writeCap () ]) )
        return ls

    def makeSpecial (self):
        n = self._username + "+_g_umgr_tag"
        (h, cap) = flmu.makeGroup (name=n, ls=self.publicDirLabelSet ())
        self.grantCaps ([cap])
        self._g_umgr_tag = h


