import sys, re, shutil, os.path, os
import subprocess

FREEZE = '/usr/share/doc/python2.5/examples/Tools/freeze/freeze.py'
FLUME_PYPATH  = os.popen ('flume-cfg pypath').read ().strip ().split (':')
FLUME_DJANGO_DIR  = os.path.join (os.popen ('flume-cfg srcdir').read ().strip (), '..', 'django')
TMPDIR = None

useless_paths = [
    '/usr/lib/python25.zip',
    '/usr/lib/python2.5/plat-linux2',
    '/usr/lib/python2.5/lib-tk',
    '/usr/local/lib/python2.5/site-packages',
    '/usr/lib/python2.5/site-packages/Numeric',
    '/var/lib/python-support/python2.5/gtk-2.0',
    '/var/lib/python-support/python2.5',
    ]

extra_modules = [
    'flume',
    'flume.flmos',
    'wikicode',
    'os',
]

django_modules = [
    'django.core.cache.backends',
    'django.core.cache.backends.simple',

    'django.db.backends.flumedb',
    'django.db.backends.flumedb.base',
    'django.db.backends.flumedb.introspection',
    'django.db.backends.flumedb.creation',
    'django.db.backends.flumedb.client',

    'django.middleware.common',
    'django.middleware.doc',

    'django.contrib.sessions.middleware',
    'django.contrib.sessions.models',
    'django.contrib.auth.middleware',
    'django.contrib.w5.models',

    'django.template',
    'django.template.context',
    'django.template.defaulttags',
    'django.template.defaultfilters',
    'django.template.loader',
    'django.template.loader_tags',
    'django.template.loader_tags',
    'django.template.loaders.app_directories',
    'django.template.loaders.eggs',
    'django.template.loaders.filesystem',
    ]

django_app_modules = [
    '',
    '.models',
    '.urls',
    '.views',
    ]

extra_pypath = [
    FLUME_DJANGO_DIR,
#    '/usr/lib/python2.5/email/mime/',
    ]

def freeze_apps (djangoapp, app_data):
    global_pypath = list (sys.path)

    for appname, scriptpath, srcdir, pypath in app_data:
        print >> sys.stderr, "Freezing %s %s" % (appname, scriptpath)
        
        new_pypath = pypath + FLUME_PYPATH + extra_pypath + global_pypath
        for p in useless_paths:
            new_pypath.remove (p)

        print >> sys.stderr, "NEW PYPATH \n%s\n" % ('\n'.join (new_pypath),)

        new_pypath = ':'.join (new_pypath)
        print >> sys.stderr, "PYPATH %s" % new_pypath

        env = os.environ.copy ()
        env['PYTHONPATH'] = new_pypath

        # Use freeze.py to create the .c files and Makefile.
        args = ['python', '-S', FREEZE, '-m', scriptpath]
        args.extend (extra_modules)
        if djangoapp:
            args.extend (django_modules)
            args.extend ([appname + suffix for suffix in django_app_modules])

        print >> sys.stderr, "CMD: %s" % (' '.join (args),)
        p = subprocess.Popen (args, cwd=TMPDIR, env=env)
        p.wait ()
        if p.returncode:
            sys.exit (1)

        # Run make
        args = ['make', '-j', '4']
        p = subprocess.Popen (args, cwd=TMPDIR, env=env)
        p.wait ()
        if p.returncode:
            sys.exit (1)

        # copy output file
        basename = os.path.basename (scriptpath)
        src = os.path.splitext (basename)[0]
        dst = os.path.join (srcdir, src)

        print >> sys.stderr, "copying from %s to %s" % (src, dst)
        shutil.copyfile (src, dst)
        
    return

def read_datafile (filename):
    rx = re.compile (r'^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$')
    ret = []

    if filename == '-':
        f = sys.stdin
    else:
        f = open (filename, 'r')
    for l in f.read ().splitlines ():
        m = rx.match (l)
        if m:
            pypath = m.group (4).split (':')
            ret.append ((m.group (1), m.group (2), m.group (3), pypath))
        else:
            raise ValueError ("Bad input file, line %s" % l)
    return ret

def usage ():
    print >> sys.stderr, "%s app_data_file" % sys.argv[0]
    sys.exit (1)

def main ():
    djangoapp = True
    
    if '-nj' in sys.argv:
        sys.argv.remove ('-nj')
        djangoapp = False

    if len (sys.argv) != 2:
        usage ()
    
    data = read_datafile (sys.argv[1])
    freeze_apps (djangoapp, data)

if __name__ == "__main__":
    main ()
    
