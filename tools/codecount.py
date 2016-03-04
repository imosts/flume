
#
# Count code for the Flume project, in a number of different
# languages.  Goal is to strip out newlines and comments.
#

import sys
import re
import os
import getopt

class Stripper:
    def __init__ (self):
        pass
    def strip (self, x):
        return x 

#-----------------------------------------------------------------------

class InsideOutsideStripper (Stripper):

    def __init__ (self, b, e):
        Stripper.__init__ (self)
        self._inside = False
        self._begin_rxx = re.compile (b)
        self._end_rxx= re.compile (e)

    def strip (self, x):

        tryit = x
        keep = ''

        while len(tryit) > 0:

            tryit = self.inside_match (tryit)
            (k, tryit) = self.outside_match (tryit)
            keep += k
            
        return keep

    def inside_match (self, x):

        y = x

        if self._inside:
            v = self._end_rxx.split (x, 1)
            if len (v) > 1:
                x = v[1]
                self._inside = False
            else:
                x = ''

        return x

    def outside_match (self, x):

        v = self._begin_rxx.split (x, 1)
        leftovers = ''
        if len (v) > 1:
            self._inside = True
            leftovers = v[1]
        return (v[0], leftovers)

#-----------------------------------------------------------------------

class PatchStripper (Stripper):

    def __init__ (self):
        Stripper.__init__ (self)
        self.rxx = re.compile ("^[+-]")

    def strip (self, x):
        if self.rxx.match (x):
            return x
        else:
            return ''

#-----------------------------------------------------------------------
    
class CcomStripper (InsideOutsideStripper):
    def __init__ (self):
        InsideOutsideStripper.__init__ (self, '/\\*', '\\*/')
        
class PythonDocStripper (InsideOutsideStripper):
    def __init__ (self):
        InsideOutsideStripper.__init__ (self, '"""', '"""')
        
#-----------------------------------------------------------------------

class EolStripper (Stripper):

    def __init__ (self, pat):
        Stripper.__init__ (self)
        self.rxx = re.compile (pat)

    def strip (self, x):
        v = self.rxx.split (x, 1)
        if len (v) > 1:
            v[0] += '\n'
        return v[0]
    
#-----------------------------------------------------------------------

class PoundStripper (EolStripper):
    def __init__ (self):
        EolStripper.__init__ (self, '#')
        
class DslashStripper (EolStripper):
    def __init__ (self):
        EolStripper.__init__ (self, '//')
        
class DslashStripper (EolStripper):
    def __init__ (self):
        EolStripper.__init__ (self, '//')

class DdashStripper (EolStripper):
    def __init__ (self):
        EolStripper.__init__ (self, '--')
        
#-----------------------------------------------------------------------

class FileReader:

    nospace_rxx =  re.compile ("\\S")
    
    def __init__ (self, name):
        self._nm = name
        self._fh = open (name, "r")
        self.strip_stack = []

    def lang_count (self, l):
        return 1

    def strip (self, x):
        for s in self.strip_stack:
            x = s.strip (x)
        return x

    def count (self):
        tot = 0
        for l in self._fh.readlines ():
            out = self.strip (l)
            if self.nospace_rxx.search (out):
                tot += 1
        return tot
    
#-----------------------------------------------------------------------

class PatchReader (FileReader):

    def __init__ (self, name):
        FileReader.__init__ (self, name)
        self.strip_stack = [ PatchStripper () ]

    def id (self):
        return "patch"

class CppReader (FileReader):

    def __init__ (self, name):
        FileReader.__init__ (self, name)
        self.strip_stack = [ CcomStripper (), DslashStripper () ]

    def id (self):
        return "c"

class PythonReader (FileReader):

    def __init__ (self, name):
        FileReader.__init__ (self, name)
        self.strip_stack = [ PythonDocStripper (), PoundStripper () ]

    def id (self):
        return "py"

class PerlReader (PythonReader):
    def id (self):
        return "pl"

class SqlReader (FileReader):

    def __init__ (self, name):
        FileReader.__init__ (self, name)
        self.strip_stack = [ SqlComStripper () ]

    def id (self):
        return "sql"
        
#-----------------------------------------------------------------------

class SkipError (Exception):

    def __init__ (self, e):
        self.value = e
    def __str__ (self):
        return repr (self.value)

#-----------------------------------------------------------------------

class Runner:

    def __init__ (self, dir, verbose = False):
        tab = [ (["T", "C", "x", "c", "cpp", "h", "i"],  CppReader),
                (["py"], PythonReader),
                (["pl"], PerlReader),
                (["sql"], SqlReader),
                (["patch"], PatchReader ) ]

        self.tab = {}
        self.verbose = verbose

        for p in tab:
            for ext in p[0]:
                self.tab[ext] = p[1]

        os.chdir (dir)

    def run1 (self, fn):
        v = fn.split ('.')
        ext = v[-1]

        if self.filt and not self.filt (fn):
            raise SkipError, fn

        klass = None
        
        if self.picker:
            klass = self.picker (fn)
            
        if klass is None:
            try:
                klass = self.tab[ext]
            except KeyError:
                raise SkipError, fn
            
        reader = klass (fn)
        return (reader.count (), reader.id ())

    def run_file (self, fn):

        try:
            (c, t) = self.run1 (fn)
            
            if self.verbose:
                print "++ %s (%s) => %d" % (fn, t, c)
            self.count[t] += c

        except SkipError:
            pass
        except KeyError:
            self.count[t] = c

    def run_dir (self, d):

        if d[0] == ".":
            return

        if self.verbose:
            print "+ run_dir (%s)" % d

        if os.path.isdir (d):

            v = os.listdir (d)
            for f in v:
                n = d + "/" + f

                if os.path.isdir (n):
                    self.run_dir (n)
                elif os.path.isfile (n):
                    self.run_file (n)
                    
        elif os.path.isfile (d):
            self.run_file (d)
            
        else:
            sys.stderr.write ("Skipped non-directory: %s\n" % d)

    def run (self, name, ds, filt = None, picker = None):

        self.count = {}
        self.filt = filt
        self.picker = picker
        
        for d in ds:
            self.run_dir (d)
        self.output (name)

    def output (self, name):
        print "Component: %s" % name
        tot = 0
        for p in self.count.items ():
            tot += p[1]
            print "\t%s => %d" % p
        print "\tTotal: %d" % tot
        
#-----------------------------------------------------------------------

class Hooks:

    r1 = re.compile ("include/flume.*\.h")
    r2 = re.compile ("flume_ev")
    rpcx = re.compile ("include/prot/.*\.x")
    pyb = re.compile ("build/.*\.py")
    prxx = re.compile ("-patch$")

    def inc_filter (self, wantEv, n):
        return not self.r1.match (n) or \
               (bool (self.r2.search (n)) == wantEv)

    def cli_filter (self, n):
        return not self.rpcx.search (n) \
               and not self.pyb.search (n) \
               and self.inc_filter (False, n)

    def cli_picker (self, n):
        if self.prxx.search (n):
            return PatchReader
        return None
    

#-----------------------------------------------------------------------

def usage ():
    sys.stderr.write ("usage: " + sys.argv[0]  + " [-v] linux/\n" +
                      "  from top of Traz checkout")
    sys.exit (2)


verbose = False

o, a = getopt.getopt (sys.argv[1:], "v")
opts = {}
for k,v in o:
    opts[k] = v
if opts.has_key ("-v"):
    verbose = True

if len(a) != 1:
    usage ()
    
r = Runner (verbose = verbose, dir = a[0])
hk = Hooks ()

#-----------------------------------------------------------------------

r.run ("RM",
       [ "libflume-ev", "srv/libflume-srv", "srv/rm", "include"],
       lambda x: hk.inc_filter (True, x) )

r.run ("FS", ["srv/fs"])
r.run ("spawn", ["srv/spawn"])
               
r.run ("IDD", [ "srv/libamysql", "srv/idd" ] )

r.run ("Cli" ,
       [ "lang", "ld.so", "libc", "flumec", "include",
         "ext-src" ],
       hk.cli_filter,
       hk.cli_picker )

r.run ("Lsm", [ "lsm" ] )

r.run ("kern", ["kern/linux-3.6.17.patch" ])
