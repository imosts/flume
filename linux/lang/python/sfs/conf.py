
"""
sfs/conf.py

A small class to parse and edit (potentially) sfs-style configuration
files
"""

import re

class Error (Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)

def endsInSlash (str):
    n = 0
    for x in str:
        if x == '\\':
            n += 1
        elif x == '#':
            return False
        elif x != '\n':
            n = 0
    return (n % 2 == 1)

def splitArgs (str, loc):
    
    NONE = 0
    SQUOTE = 1
    DQUOTE = 2
    ARG = 3
    SPACE = 4
    
    mode = NONE
    arg = ''
    args = []

    escape = False
    
    for c in str:
        if c.isspace ():
            if mode == ARG:
                args += [ arg ]
                arg = ''
                mode = SPACE
            elif escape:
                arg += c
                escape = False
            elif mode == SQUOTE or mode == DQUOTE:
                arg += c
                
        elif c ==  '\\':
            if mode != SPACE:
                if escape:
                   arg += c 
                   escape = False
                else:
                    escape = True
                    if mode == NONE:
                        mode = ARG

        elif c == '\'':
            if mode == SQUOTE:
                if escape:
                    arg += c
                else:
                    mode = ARG
            elif mode == NONE or mode == SPACE:
                mode = SQUOTE
            else:
                arg += c
            escape = False
            
        elif c == '\"':
            if mode == DQUOTE:
                if escape:
                    arg += c
                else:
                    mode = ARG
            elif mode == NONE or mode == SPACE:
                mode = DQUOTE
            else:
                arg += c
            escape = False

        else:
            if mode == NONE or mode == SPACE:
                mode = ARG
            arg += c
            escape = False

    if mode == DQUOTE or mode == SQUOTE or escape:
        raise Error, "%s: end of line in open quote / esc seq" % loc
    elif mode == ARG:
        args += [ arg]

    return args
            
class ParsedLine:
    """A line from the file that's been stripped and split, but still
    maitaining the original formatting."""
    
    comment_rxx = re.compile ("(?P<ws>\s*)(?P<body>[^#]+)(?P<com>#(.*))?")
    env_rxx = re.compile ("(?P<name>[^=]+)=(?P<value>.*)")

    def __init__ (self, s, progs, loc):
        self._orig = s
        self._changed = False
        self._ws = ""
        self._v = []
        self._com = ""
        self._body = ""
        self._env = []
        self._program = None
        self._command = None
        
        x = self.comment_rxx.match (s)
        if x is not None: 
            for n in ['ws', 'body', 'com']:
                el = x.group (n)
                if el is not None:
                    setattr (self, "_" + n , el)

            v = splitArgs (self._body, loc)
            if len (v) > 0:
                it = iter (v)
                self._command = it.next ()

                if self._command in progs:
                    for i in it:
                        x = self.env_rxx.match (i)
                        if x is not None:
                            self._env += [ (x.group ('name'),
                                            x.group ('value')) ]
                        else:
                            self._program = i
                            break
                    
                self._v = list (it)

    def cmd (self):
        return self._command

    def program (self):
        return self._program

    def setArgv (self, v):
        self._v = v
        self._changed = True

    def argv (self):
        return self._v

    def toLine (self):
        if self._changed:
            args = [ self.cmd (),
                     self.program (),
                     ' '.join ( ["%s=%s" % (n,v) for (n,v) in self._env ] ),
                     ' '.join (self._v)
                     ]
            return self._ws + "\t".join (self._v) + self._com
        else:
            return self._orig
        
class Parse:
    """Parse and translate an input sfs-style config file."""

    def __init__ (self, fn):
        self._infn = fn
        self._out = []
        self._dispatch_tab = {}
        
    def open (self):
        self._infh = open (self._infn, "r")

    def read (self):
        self.open ()
        self._lines = self._infh.readlines ()

    def loc (self, ln):
        return "%s:%d" % (self._infn, ln)
        
    def parse (self):
        """Given an input file that's been split into lines,
        parse it and potentially translate it."""

        progs = set ()
        for x in self._dispatch_tab.items ():
            if x[1][1]:
                progs.add (x[0])
        
        self.read ()

        ln = 1
        line = ''
        continuedLine = False

        loc = None
        
        for l in self._lines:
            if endsInSlash (l):
                line += l[0:-2] + ' '
                ln += 1
                continuedLine = True
                continue
            else:
                line = l
                continuedLine = False

            loc = self.loc (ln)
                
            pl = ParsedLine (line, progs, loc)
            cmd = pl.cmd ()
            newl = None
            if cmd is not None:
                try:
                    (fn,isProg) = self._dispatch_tab[cmd]
                    newl = fn (pl, loc)
                except KeyError, e:
                    pass
            if newl is None:
                newl = pl
            self._out.append (newl)
            ln += 1

        if continuedLine:
            raise Error, \
                  "%s: EOF encountered when looking for line continuation." % \
                  loc
