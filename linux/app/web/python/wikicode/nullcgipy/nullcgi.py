import sys

def optimize_pypath ():
    # Optimze the python path
    useless_paths = [
        '/usr/lib/python25.zip',
        '/usr/lib/python2.5/plat-linux2',
        '/usr/lib/python2.5/lib-tk',
        '/usr/local/lib/python2.5/site-packages',
        '/usr/lib/python2.5/site-packages/Numeric',
        '/var/lib/python-support/python2.5/gtk-2.0',
        '/var/lib/python-support/python2.5',
        ]

    high_priority_paths = [
        '/usr/lib/python2.5/lib-dynload',
        '/usr/lib/python2.5/site-packages',
        ]

    low_priority_paths = [
        '/usr/lib/python2.5',
        ]

    for p in useless_paths:
        if p in sys.path:
            sys.path.remove (p)

    for p, i in zip (high_priority_paths, range (len (high_priority_paths))):
        if p in sys.path:
            sys.path.remove (p)
            sys.path.insert (i, p)

    for p in low_priority_paths:
        if p in sys.path:
            sys.path.remove (p)
            sys.path.append (p)

    print >> sys.stderr, "PYPATH %d %s" % (len (sys.path), sys.path)


if __file__ == '<frozen>':
    optimize_pypath ()

# Kill the RPC fd, rather than importing wikicode package
import os
import flume.flmos as flmo
if os.environ.has_key ('RPC_TAG'):
    fd = flmo.claim (os.environ['RPC_TAG'])
    os.close (fd)
    
#import wikicode, os, sys
#if os.environ.has_key (wikicode.RPC_TAG_ENV):
#    global rpc_proxy
#    try:
#        rpc_fd, rpc_proxy = wikicode.to_rpc_proxy (os.environ[wikicode.RPC_TAG_ENV])
#    except OSError:
#        pass

output = ("Status: 200 OK\r\n"
          "Content-type: text/html\r\n"
          "\r\n"
          "nullcgi.py!")

sys.stdout.write (output)
