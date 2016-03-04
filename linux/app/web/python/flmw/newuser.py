
"""flumeweb.newuser

Libraries for making a new user on the system.
"""

__revision__ = "$Id$"

import flume
import sys, os, string, re

SALT = "Blah blah blah blah blah 39"

class UserFactory:

    def __init__ (self, dirh):
        pass

    def create (self, name, pw):
        u = User (name, pw)
        u.create ()
        return u

class User:
    
    def __init__ (self, name, pw):
       self._name = name
       self._pw = pw
       
    def hname (self, sffx):
        return "user_%s_%s" % (self._name, sffx)

    def create (self):
        self.createWriteCap ()
        self.createGroup ()

    def createWriteCap (self):
        fl = flume.HANDLE_OPT_PERSISTENT | flume.HANDLE_OPT_IDENTIFIER
        h = flume.new_handle (fl, self.hname ("w"))
        self._w = h

    def mkpw (self):
        ctx = sha.new ()
        ctx.update (self._pw)
        ctx.update (SALT)
        return ctx.digest ()

    def createGroup (self):
        lbl = flume.Label ( [ self._w ])
        ls = flume.LabelSet ( { "O" : flume.Label ( lbl ) } )
        self._g = flume.new_group (self.hname ("g"), ls)
        flume.make_nickname (self._g, self._name)
        flume.add_to_group (self._g, lbl)
        flume.make_login (self._g, self.mkpw ())

