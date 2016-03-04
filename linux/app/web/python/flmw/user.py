
"""flmw.user

Libraries for manipulating users on a Flume web syste.
"""

import flume
import flume.flmos as flmo
import flume.util
import flmw.group as flmwg
import os.path
import re
import flmw
import flmw.principal as flmwp
import sha
import sys

__revision__ = "$Id"

def hashpw (pw, salt):
    x = sha.sha ()
    x.update (salt + "--" + pw + "--" + salt)
    return x.hexdigest ()

def list2str (name, v):
    if len (v) != 1:
        raise ValueError, "Expected 1 argument, got %d args" % len (v)
    return v[0]

def getgroup (name, v):
    if len (v) != 3:
        raise ValueError, "Expected 3 arguments, got %d args" % len (v)
    return (flmwg.UserGroup (gid = v[0], gname = name), v[1], v[2])

class GroupInvite:

    def __init__ (self, group, group_h, pw, privs, inviter):
        self._group = group
        self._group_h = group_h
        self._pw = pw
        self._privs = privs
        self._inviter = inviter

    def reqPrivs (self):
        flmo.req_privs (self._group_h, self._pw)
        return self._group_h

    def __str__ (self):
        return str (self._group)

def getGroupInvite (name, v):
    if len (v) != 5:
        raise ValueError, "Expected 5 arguments, got %d args" % len (v)

    group = flmwg.UserGroup (gname = name, gid = v[0])
    return GroupInvite (group = group,
                        group_h = flmo.Handle (v[1]),
                        pw = v[2],
                        privs = group.strToPrivs (v[3]),
                        inviter = v[4])

class User (flmwp.Principal):

    def _makeAttrMap (self):
        flmwp.Principal._makeAttrMap (self)
        self._addUmgrAttributes ()

    def _pwFileAttrMap (self):
        m = { "PasswordSalt" : ("_pw_salt", ),
              "PasswordHash" : ("_pw_hash", ),
              "LoginToken" : ("_login_token", ) }
        return m

    def __init__ (self, uname=None, uid=None, umgr=None):
        flmwp.Principal.__init__ (self, uname=uname, uid = uid, umgr = umgr)
        self._pw_attr_map = self._pwFileAttrMap ()

    def makeLogin (self, pw):
        flmwp.Principal.makeLogin (self, pw)
        self._pw_salt = flume.random_str (10)
        self._pw_hash = hashpw (pw, self._pw_salt)

    def writePwFile (self):
        (fn, h) = self.createPwFile ()
        self.writeFile (fn, h, self._pw_attr_map)

    def readPwFile (self):
        (fn, h) = self.openPwFile ()
        self.readFile (fn, h, self._pw_attr_map, list2str)

    def readGroupInvitesFile (self):
        (fn, h) = self.openGroupInvitesFile ()
        self._group_invites = {}
        self.readFile (fn, h, None, getGroupInvite, self._group_invites)

    def readGroupsFile (self):
        (fn, h) = self.openGroupsFile ()
        self._user_groups = {}
        self.readFile (fn, h, None, getgroup, self._user_groups)

    def openGroupsFile (self):
        fn = self.groupsFile ()
        return self.openFile (fn)

    def openGroupInvitesFile (self):
        fn = self.groupInvitesFile ()
        
        # the group invites file has lower integrity, since other users
        # have written to it; thus we should disable integrity checks...
        return self.openFile (fn, False)

    def openPwFile (self):
        fn = self.pwFile ()
        return self.openFile (fn)

    def createPwFile (self):
        fn = self.pwFile ()
        ls = self.pwFileLabelSet ()
        return (fn, flmo.open (name = fn, flags = "cw", labelset=ls, mode=0600))
    
    def pwFile (self):
        return os.path.join (self.flumeDir (), flmw.PW_FILE)

    def tagsFileLabelSet (self):
        ls = flmwp.Principal.tagsFileLabelSet (self)
        return ls

    def login (self, givenpw):
        pwh = hashpw (pw=givenpw, salt=self._pw_salt)
        if pwh != self._pw_hash:
            raise flmw.UserLoginError, "bad password given"
        flmo.req_privs (self.groupCap (), self._login_token)

    def pwFileLabelSet (self):
        return flmo.LabelSet ( I=self.integrityLabel (),
                              O=flmo.Label ([ self.writeCap ()]),
                              S=flmo.Label ([ self._r_umgr_tag ]) )

    def writeFiles (self):
        flmwp.Principal.writeFiles (self)
        self.writePwFile ()

    def readFiles (self):
        flmwp.Principal.readFiles (self)
        self.readPwFile ()

    def exportProtectDir (self):
        return os.path.sep.join ( [ self.homeDir (),
                                    flmw.DIR_NO_INTEGRITY,
                                    flmw.DIR_EXPORT_PROTECT ] )
    def integrityProtectDir (self):
        return os.path.sep.join ( [ self.homeDir (),
                                    flmw.DIR_USER_INTEGRITY ] )

    def makeHomeDir (self):
        flmwp.Principal.makeHomeDir (self)

        # make a directory for the user with user integrity, to store user
        # integrity files in.
        d = os.path.sep.join ([ self.homeDir (), flmw.DIR_USER_INTEGRITY ])
        ls = self.homeDirLabelSet ()
        ls.set_I (flmo.Label ([self._i_tag]))
        flmo.mkdir (path=d, mode = 0755, labelset=ls)
        
        # make a directory for the user with no integrity, to store low
        # integrity crapola into (relative to the user).
        d = os.path.sep.join ([ self.homeDir (), flmw.DIR_NO_INTEGRITY ])
        ls = self.homeDirLabelSet ()
        ls.set_I()
        flmo.mkdir (path=d, mode = 0755, labelset=ls)

        # make a subdir of NO_I for storing tainted stuff; need
        # to lower our integrity so that we can traverse the low
        # integrity dir we just created
        d = os.path.sep.join ([d, flmw.DIR_EXPORT_PROTECT])
        ls.set_S (flmo.Label ([ self._e_tag]) )
        I_orig = flmo.get_label (flume.LABEL_I)
        flmo.set_label (flume.LABEL_I)
        flmo.mkdir (path = d, mode = 0755, labelset = ls)
        flmo.set_label (flume.LABEL_I, I_orig)

        #
        # Make a group invites files
        #
        self.clearGroupInvitesFile ()

    def groupsFile (self):
        return os.path.sep.join ([ self.flumeDir (), flmw.GROUPS_FILE] )

    def groupInvitesFile (self):
        return os.path.sep.join ([ self.flumeDir (), flmw.GROUP_INVITES_FILE ])

    def groupInvitesLabelSet (self):
        #
        # Also have umgr integrity tag?
        #
        return flmo.LabelSet ( S = flmo.Label ([ self._e_umgr_tag ]), 
                              O = flmo.Label ([ self.writeCapUmgr () ]) )

    def groupsFileLabelSet (self):
        return self.tagsFileLabelSet ()

    def appendToInvitesFile (self, gname, gid, h, tok, privs, admin):
        gf = self.groupInvitesFile ()
        ls = self.groupInvitesLabelSet ()
        fields = [ gname, gid, h.armor32(), tok, privs, admin ]
        self.appendLineToGroupsFile (gf, ls, fields, False)

    def appendToGroupsFile (self, grp, caps, s):
        gf = self.groupsFile ()
        # XXX - only write one capability to per group for now...
        fields = [ grp._username, grp._uid, caps[0].armor32(), s]
        ls = self.groupsFileLabelSet ()
        self.appendLineToGroupsFile (gf, ls, fields, True)

    def appendLineToGroupsFile (self, gf, ls, fields, creat):

        
        if creat and not os.path.exists (gf):
            fd = flmo.open (name=gf,flags="wc", mode=0644, labelset=ls)
            fd.close ()
        S_orig = flmo.get_label (flume.LABEL_S)
        flmo.set_label (flume.LABEL_S, ls.get_S ())

        try:
            fd = open (gf, "a")

            line = "\t".join (fields) + "\n"
            fd.write (line)
            fd.close ()
            
        finally:
            flmo.set_label (flume.LABEL_S, S_orig)
            

    def addSelfToUserGroup (self, g, privs):
        """
        Add ourselves to the given user group, with the
        privilege specified.
        """
        I_orig = flmo.get_label (flume.LABEL_I)
        gls = flmo.stat_group (self._g_tag)
        flmo.set_label (flume.LABEL_I, gls.get_I ())
        caps = g.getCapabilities (privs)
        flmo.add_to_group (self._g_tag, caps)
        self.appendToGroupsFile (g, caps, g.privsToStr (privs) )
        flmo.set_label (flume.LABEL_I, I_orig)

    def clearGroupInvitesFile (self):
        ls = self.groupInvitesLabelSet ()
        fn = self.groupInvitesFile ()
        fd = flmo.open (name=fn, flags="wc", mode=0644, labelset=ls)
        fd.write ("# Group Invitations File\n")
        fd.close ()
        

    def acceptAllGroupInvites (self):
        """
        Read all invitations from the invites file, and then
        accept all of them into our groups file.
        """
        
        self.readGroupInvitesFile ()
        self.clearGroupInvitesFile ()

        # after reading the group invites files, we can now raise
        # our integrity level.
        I_orig = flmo.get_label (flume.LABEL_I)
        flmo.set_label (flume.LABEL_I, I_orig + self.integrityLabel ())

        caps = []
        n = 0
        for (name, gi) in self._group_invites.iteritems ():
            try:
                c = gi.reqPrivs ()
                grp = gi._group
                privs = gi._privs
                privs_s = grp.privsToStr (privs)
                caps.append (gi.reqPrivs ())
                self.appendToGroupsFile (grp, [c], privs_s)
                n += 1
            except flume.LoginError, e:
                sys.stderr.warn ("Login Error: For group %s: %s" % (gi, e))
            except flume.ExpirationError, e:
                sys.stderr.warn ("Expiration Error: For group %s: %s"
                                 % (gi, e))

        flmo.add_to_group (self._g_tag, caps)
            
        # restore integrity as it was before
        flmo.set_label (flume.LABEL_I, I_orig)

        return n
