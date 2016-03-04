import sys

PROFILE = False


if False:
    import fastimporter;
    fastimporter.register ();

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

    #print >> sys.stderr, "PYPATH %d %s" % (len (sys.path), sys.path)


def main ():
    if __file__ == '<frozen>':
        optimize_pypath ()

    if PROFILE:
        #import time, sys
        #sys.stderr.write ("worker start time %0.3f\n" % time.time ())
        from flume.profile import start, print_delta, print_total
        start ()
        print_delta ("worker begin")

    import os, w5djangoutil
    from wikicode.prepare import is_prepare, prepare_uri, prepare_stags

    w5djangoutil.setup ()
    
    if is_prepare ():    
        from django.conf import settings
        from django.core import urlresolvers
        from django.core.handlers.wsgi import WSGIRequest

        # Toolbar is notifying this app that the user is adding S tags.
        newstags = prepare_stags ()

        environ = dict (os.environ)
        from wikicode import W5Uri
        environ['PATH_INFO'] = str (W5Uri (uri=prepare_uri (), trusted=False))
        request = WSGIRequest (environ)

        # Get a resolver that uses the URL configuration in settings.py
        resolver = urlresolvers.RegexURLResolver(r'^/', settings.ROOT_URLCONF)
        callback, callback_args, callback_kwargs = resolver.resolve(request.path)
        response = callback (request, *callback_args, **callback_kwargs)
        print "response is [%s]" % response

    else:
        # Just run the app like normal
        from django.core.servers.cgi import runcgi
        runcgi()

        if False:
            fastimporter.print_hints ()
            fastimporter.print_dummies ()

    if PROFILE:
        print_total ('worker end')

if __name__ == "__main__":
    if PROFILE:
        import cProfile
        cProfile.run ('main ()')
    else:
        main ()
