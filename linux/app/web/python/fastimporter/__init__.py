import imp, sys, re

"""
This package implements an import hook that reads a hints file to
speed up finding modules.  We use hints for the bulk of the python
packages like in base-python, wikicode and django libraries.

Note, that if you add something to the hints, this importer will not
check to see that the .pyc file is up-to-date.  So, you will have to
recompile your .py files yourself.  The makefiles do this for wikicode
and django, but currently, it does not compile application code like
views.py and models.py.

TODO:
It also adds None to sys.modules for commong modules like
'wikicode.os' and 'wikicode.sys'.  This prevents the python importer
from searching for common modules like 'os' and 'sys' in 'wikicode'
and every other package.

"""

MODE_FAST   = 1
MODE_SLOW   = 2
MODE_RECORD = 3
_mode = MODE_SLOW

PKG_DESC    = ('', '', imp.PKG_DIRECTORY)
CBI_DESC    = ('', '', imp.C_BUILTIN)
SO_DESC     = ('.so', 'rb', imp.C_EXTENSION)
MODULE_DESC = ('module.so', 'rb', imp.C_EXTENSION)
PY_DESC     = ('.py', 'U', imp.PY_SOURCE)
PYC_DESC    = ('.pyc', 'rb', imp.PY_COMPILED)

desc2str = {PKG_DESC: 'pkg',
            CBI_DESC: 'cbi',
            SO_DESC: 'so',
            MODULE_DESC: 'module.so',
            PY_DESC: 'py',
            PYC_DESC: 'pyc'}
str2desc = dict ([(p[1], p[0]) for p in desc2str.items ()])

# This is what data would look like:
data = """HINT Cookie /usr/lib/python2.5/Cookie.pyc pyc
HINT DBV /disk/yipal/flume/run/lib/python2.5/site-packages/DBV pkg
DUMMY djangotools.django
"""

# Maps fullnames to (pathname, desc)
known_modules = {
  'testmodule': ('/home/am7/yipal/fun/testmodule.pyc', PYC_DESC),
  'testpackage': ('/home/am7/yipal/fun/testpackage', PKG_DESC),
  'testpackage.submodule': ('/home/am7/yipal/fun/testpackage/submodule.pyc', PYC_DESC),
}

found_modules = {}

def dbg (s):
    #print >> sys.stderr, s
    pass

def get_mode ():
    global _mode
    return _mode

def print_hints ():
    import os
    
    keys = found_modules.keys ()
    keys.sort ()
    for k in keys:

        m = found_modules[k]
        if m[1] == PY_DESC:
            # If we can find a valid .pyc file, use that instead of the .py file.
            try:
                stat_py = os.stat (m[0])

                pyc_path = m[0] + 'c'
                stat_pyc = os.stat (pyc_path)

                if stat_py.st_mtime <= stat_pyc.st_mtime:
                    m = (pyc_path, PYC_DESC)
            except OSError, e:
                import errno
                if e.errno != errno.ENOENT:
                    raise
        
        print "HINT %s %s %s" % (k, m[0], desc2str [m[1]])

def print_dummies ():
    dummies = [k for k in sys.modules.keys () if sys.modules[k] is None]
    for d in dummies:
        print "DUMMY %s" % d


def read_hints ():
    hints_rx = re.compile (r'^HINT\s+(\S+)\s+(\S+)\s+(\S+)\s*$')
    dummy_rx = re.compile (r'^DUMMY\s+(\S+)*$')

    global known_modules
    for l in data.splitlines ():
        m = hints_rx.match (l)
        if m:
            if str2desc[m.group (3)] != CBI_DESC:
                known_modules[m.group (1)] = (m.group (2), str2desc[m.group (3)])
            continue
        m = dummy_rx.match (l)
        if m:
            sys.modules[m.group (1)] = None
            continue
        print "parse error in hints: %s" % l

class FastImporter (object):
    def find_module (self, fullname, path=None):
        dbg ("FastImporter.find_module (fullname %s, path %s)" % (fullname, path))
        #dbg ("sys.modules keys %s" % (sys.modules.keys (),))
        #dbg ("sys.modules dummies %s" % ([e[0] for e in sys.modules.items() if e[1] is None],))

        mode = get_mode ()
        if mode == MODE_FAST:
            try:
                pathname, desc = known_modules[fullname]
                if desc == PKG_DESC:
                    f = None
                else:
                    f = open (pathname, desc[1])

                dbg ("HIT on %s -> %s" % (fullname, pathname))
                return FastLoader (f, pathname, desc)
            except KeyError:
                return None

        elif mode == MODE_SLOW:
            return None

        elif mode == MODE_RECORD:
            try:
                idx = fullname.rfind ('.')
                name = fullname[idx+1:]

                # Searches sys.path for <name>.
                file, pathname, desc = imp.find_module (name, path)
                found_modules[fullname] = (pathname, desc)
                
                dbg ("  imp.find_module returned %s" % ((file, pathname, desc),))
                return None
            except ImportError:
                dbg ('  got ImportError')
                return None
        else:
            raise AssertionError ("Invalid mode!")
            

class FastLoader (object):
    def __init__ (self, file, pathname, desc):
        self.file = file
        self.pathname = pathname
        self.desc = desc

    def load_module(self, fullname):
        if False and self.desc == PKG_DESC and get_mode () == MODE_FAST:
            # Avoid searching directory for 4 x __init__ files.
            path = self.pathname + "/__init__.pyc"
            f = open (path, 'rb')
            try:
                dbg ("  LOAD_COMPILED %s" % fullname)
                m = imp.load_compiled (fullname, path, f)
                #dbg ("  imp.load_module 1 returned %s" % (m,))

                # pkgs need __path__ so that find_module gets called with the path for submodules
                m.__path__ = self.pathname 
                return m
            finally:
                f.close ()
        else:
            try:
                dbg ("  LOAD_MODULE %s" % fullname)
                m = imp.load_module (fullname, self.file, self.pathname, self.desc)
                #dbg ("  imp.load_module 2 returned %s" % (m,))
                return m
            finally:
                if self.file:
                    self.file.close ()

def register ():
    read_hints ()
    sys.meta_path.append (FastImporter ())
    print >> sys.stderr, "REGISTERED IMPORTER"
