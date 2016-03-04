
"""flmw.principal

A principal on the system, such as a regular user, or perhaps a privileged
user like the UserMgr"""

import flume
import flume.flmos as flmo
import flume.util as flmu
import os.path
import flmw
import sys


def str2handle (name, val):
    if len(val) != 1:
        raise ValueError, \
              "Expected a single handle arg, got %d args" % len(val)
    return flmo.Handle (x=val[0], nm=name)

class Principal:
    
    def _makeAttrMap (self):
        m = { "ExportProtect" :  ("_e_tag", True, "ep" ),
              "ReadProtect" : ("_r_tag", True, "rp") ,
              "WriteProtect" : ("_w_tag", True, "wp"),
              "IntegrityProtect" : ("_i_tag", True, "ip"),
              "GroupHandle" : ("_g_tag", False) }
        self._attr_map = m

    def _addUmgrAttributes (self):
        # add an extra attribute -- export protection that the
        # user manager also knows about
        self._attr_map["ExportProtectUmgr"] = ("_e_umgr_tag", True, "ep")
        self._attr_map["ReadProtectUmgr"] = ("_r_umgr_tag", True, "rp")
        self._attr_map["WriteProtectUmgr"] = ("_w_umgr_tag", True, "wp")

    def __init__(self, uname=None, uid=None, umgr=None):
        """auid = 'Armored User ID'"""
        self._username = uname
            
        self._makeAttrMap ()
        self._capset = set ()
        self._uid = uid
        self._home_dir = None
        
        for i in self._attr_map.items () :
            setattr (self, i[1][0], None)

        #
        # for users and UserGroups, we need to add the user managers'
        # integrity tag to our tag.
        #
        self._i_label = None
        if umgr is not None:
            self._i_umgr = umgr.integrityLabel ().clone ()
        else:
            self._i_umgr = flmo.Label ([])

    def makeTags (self):
        """Allocate those tags (with the RM) that don't currently
        exist for this particular user."""
        for i in self._attr_map.items ():
            attrname, mktag = i[1][0:2]
            if mktag and getattr (self, attrname) is None:
                nm = self.tagName (attrname)
                flags = i[1][2]
                (h, cl) = flmu.makeTag (flags=flags, name=nm)
                setattr (self, attrname, h)
                self.grantCaps (cl)
            

    def userId (self):
        """Return a frozen representation of the root label for a given
        user, such as the one used to identifier the user's home directory."""
        
        if self._uid is None:
            self._uid = self.homeDirLabelSet ().to_filename ()
        return self._uid

    def grantCaps (self, l):
        for c in l:
            self._capset.add (c)

    def setIntegrityTag (self, i):
        self._i_tag = i

    def integrityLabel (self):
        if self._i_label is None:
            lbl = self._i_umgr
            lbl += [ self._i_tag ]
            self._i_label = lbl
        return self._i_label
    
    def writeTag (self):
        return self._w_tag
    
    def writeTagUmgr (self):
        return self._w_umgr_tag

    def homeDir (self):
        if self._home_dir is None:
            self._home_dir = os.path.sep.join ([ "", flmw.IHOME,
                                                 self.userId() ])
        return self._home_dir

    def homeDirLabelSet (self):
        return flmo.LabelSet ( I = self.integrityLabel (),
                              O = flmo.Label ([ self.writeTag () ]) )
        
    def makeHomeDir (self):
        hd = self.homeDir ()
        ls = self.homeDirLabelSet ()
        flmo.mkdir (path=hd, mode=0755, labelset=ls)
        td = os.path.sep.join ( [ hd, flmw.DOT_FLUME, flmw.TAGS_FILE   ])
        flmu.mkdirAll (path=td, mode=0755, labelset=ls, stopat = -1)
        return hd

    def flumeDir (self):
        return os.path.join (self.homeDir (), flmw.DOT_FLUME)

    def readTag (self, line, attrs, fn, outdict):
        line = (line.split("#"))[0].strip ()
        if len(line) > 0:
        
            x = line.split ()
            if len(x) < 2:
                raise ValueError, \
                      "parse error: got %d args but expected >=2" % len (x)
        
            n = x[0]
            rest = x[1:]
            if attrs is not None:
                pair = attrs.get(n)
                if pair is None:
                    raise ValueError, "unknown field in file: %s" % n
                attr = pair[0]

                # Use the input function to convert this thing to an object
                t = fn (n, rest)
                setattr (self, attr, t)
                    
            elif outdict is not None:
                outdict[n] = fn (n, rest)
                

    def tagsFile (self):
        return os.path.join (self.flumeDir (), flmw.TAGS_FILE)

    def writeTags (self):
        (fn, h) = self.createTagsFile ()
        self.writeFile (fn, h, self._attr_map, lambda x: x.armor32())

    def writeFile (self, filename, filehandle, attrs, func=None):
        for i in attrs.items () :
            a = getattr (self, i[1][0])
            if a is not None:
                if func is not None:
                    a = func (a)
                filehandle.write ("%s\t%s\n" % (i[0], a))
        filehandle.close ()

    def writeCap (self):
        """Output this user's write capability."""
        return self.writeTag().toCapability (flume.CAPABILITY_GROUP_SELECT)

    def writeCapUmgr (self):
        return self.writeTagUmgr().toCapability (flume.CAPABILITY_GROUP_SELECT)

    def groupCap (self):
        """Output this user's group select capability."""
        return self._g_tag.toCapability (flume.CAPABILITY_GROUP_SELECT)

    def groupTag (self):
        """Output this user's group tag."""
        return self._g_tag

    def tagName (self, tn):
        return self._username + "+" + tn

    def makeGroup (self):
        n = self.tagName ("_g_tag")
        (h, cap) = flmu.makeGroup (name=n, ls=self.groupObjectLabelSet ())
        flmo.add_to_group (h, flmo.Label ( self._capset))
        self.grantCaps ([cap])
        self._g_tag = h
        return (h, cap)

    def makeLogin (self, pw):
        self._login_token = flmo.make_login (self.groupCap ())
        
    def loginToken (self):
        return self._login_token

    def makeSpecial (self):
        """Specialized by subclasses."""
        return True

    def setIntegrity (self):
        """Set the process integrity level to that of the user."""
        label = self.integrityLabel ()
        flmo.set_label (typ = flume.LABEL_I, label = label)

    def writeFiles (self):
        self.writeTags ()

    def readFiles (self):
        self.readTags ()

    def make (self,pw=None):
        self.makeTags ()
        self.makeSpecial ()
        self.makeGroup ()
        self.makeLogin (pw)
        self.writeFiles ()

    def groupObjectLabelSet (self):
        ls = flmo.LabelSet (O = flmo.Label ([ self.writeCap () ]),
                            I = self.integrityLabel () )
        return ls

    def tagsFileLabelSet (self):
        ls = flmo.LabelSet (I = self.integrityLabel (), 
                            O = flmo.Label ([ self.writeCap () ]) )
        return ls

    def createTagsFile (self):
        fn = self.tagsFile ()
        ls = self.tagsFileLabelSet ()
        return (fn, flmo.open (name=fn, flags="cw", labelset = ls, mode=0644))

    def openTagsFile (self):
        fn = self.tagsFile ()
        return self.openFile (fn)

    def openFile (self, fn, icheck = True):

        # read the flume labels on the file
        ls = flmo.stat_file (fn)

        # get our label now
        S = flmo.get_label (flume.LABEL_S)
        O = flmo.get_label (flume.LABEL_O)

        # make sure that we can can back to our label after setting
        # our label to that of the file
        if not ls.get_S ().subsetOf ([O, S], flume.COMPARE_SUBTRACT) :
            raise flume.DeclassificationError, \
                  "cannot declassify user's tags file"
        
        # read the flume labels on the home dir
        ls_hd = flmo.stat_file (self.homeDir ())

        # make sure that file has the user's integrity label
        if icheck and ls_hd.get_I () != ls.get_I () :
            raise flume.IntegrityError, \
                  "User's tag file ('%s') has insufficient Int (%s v. %s)" \
                  % ( fn, ls_hd.get_I (), ls.get_I ())

        # Get an endpoint that captures the file's **secrecy** but not
        # its **integrity**.
        expanded_S = S + ls.get_S ()
        ls_ep = flmo.LabelSet ( S = expanded_S )
        fh = flmo.open (name=fn, flags="r", labelset=ls, endpoint = ls_ep)
        
        return (fn, fh)
            
    def readTags (self):
        (fn, h) = self.openTagsFile ()
        self.readFile (fn, h, self._attr_map, str2handle)

    def readFile (self, filename, filehandle, attrs, func = lambda x: x,
                  outdict = None):
        n = 0
        
        for l in filehandle:
            n = n + 1
            try:
                self.readTag (l, attrs, func, outdict)
            except Exception, e:
                sys.stderr.write ("%s:%d: %s\n" % (filename, n, str (e)))

        filehandle.close ()
                                           
    def userMgrCaps (self):
        """Return the capability that should be granted to the
        user manager (for declassifying our tags file)."""
        return [ self._e_umgr_tag.toCapability (flume.CAPABILITY_SUBTRACT),
                 self._r_umgr_tag.toCapability (flume.CAPABILITY_SUBTRACT),
                 self._r_umgr_tag.toCapability (flume.CAPABILITY_ADD),
                 self._w_umgr_tag.toCapability (flume.CAPABILITY_GROUP_SELECT) ]
        
