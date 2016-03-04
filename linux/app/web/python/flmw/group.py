
"""flmw.group

A group is a principal that many users can act on behalf of.
"""

import flume
import flmw.principal as flmwp
import flume.flmos as flmo
import flume.util as flmu

ADMIN = 0x1
READ =  0x2
WRITE = 0x4

class UserGroup (flmwp.Principal):

    def makeGroupFromTags (self, name, lst):
        caps = []
        for p in lst:
            caps += flmu.makeCaps (getattr (self, p[0]), p[1])
                    
        (h, gcap) = flmu.makeGroup (name, self.groupObjectLabelSet ())
        flmo.add_to_group (h, flmo.Label (caps))
        return (h, gcap)

    def _makeAttrMap (self):
        flmwp.Principal._makeAttrMap (self)
        self._addUmgrAttributes ()
        self._attr_map["GroupReadPrivileges"] = ("_g_r_tag", False)
        self._attr_map["GroupAllPrivileges"] = ("_g_rw_tag", False)

    def __init__(self, gname=None, gid=None, umgr=None):
        flmwp.Principal.__init__(self, uname=gname, uid=gid, umgr=umgr)

    def getCapabilities (self, privs):
        ret = []
        tab = [ ( ADMIN, self.adminGroupCap ),
                ( READ , self.readGroupCap  ),
                ( WRITE, self.writeGroupCap ) ]
        
        for p in tab:
            if privs & p[0]:
                ret += [ p[1]() ]
                
        return ret

    def __str__ (self):
        return "Group (%s,%s)" % (self._username, self._uid)

    def adminGroupCap (self):
        return self.groupCap ()

    def readGroupCap (self):
        return self._g_r_tag.toCapability (flume.CAPABILITY_GROUP_SELECT)

    def writeGroupCap (self):
        return self._g_rw_tag.toCapability (flume.CAPABILITY_GROUP_SELECT)

    def privsToStr (self, privs):
        tab = [ ( ADMIN, "a" ),
                ( READ, "r" ),
                ( WRITE, "w" ) ]
        ret = ""
        for p in tab:
            if privs & p[0]:
                ret += p[1]
        return ret

    def strToPrivs (self, ins):
        out = 0
        tab = { "a" : ADMIN,
                "r" : READ,
                "w" : WRITE }
        for c in ins:
            out = out | tab[c]
        return out
            
    def makeGroup (self):
        flmwp.Principal.makeGroup (self)

        read = [ ("_e_tag", "-"),
                 ("_r_tag", "-+"),
                 ("_e_umgr_tag", "-") ]

        (h, cap) = self.makeGroupFromTags ( self.tagName ("_g_r_tag"), read )
        self.grantCaps ([cap])
        self._g_r_tag = h

        write = read + [ ("_w_tag", "s"),
                         ("_i_tag", "+") ]

        (h, cap) = self.makeGroupFromTags ( self.tagName ("_g_rw_tag"), write)
        self.grantCaps ([cap])
        self._g_rw_tag = h
        
