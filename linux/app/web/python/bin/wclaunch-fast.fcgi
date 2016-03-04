#!/usr/bin/python

import os, sys
import flume.flmos as flmo
from flume.labelsetdesc import LabelSetDesc

import wikicode
from wikicode.launcher import wclauncher


PROFILE = False
if PROFILE:
    import cProfile
    e = None
    sr = None
    ret = None

acl_cache = {}
tag_cache = {}
def launch (environ, start_response):
    wcl = wclauncher (environ, acl_cache, tag_cache)
    respcode, headers, output = wcl.get_response ()

    # Send the response back to web-server
    start_response(respcode, headers)
    return output

def launch2 ():
    global ret
    ret = launch (e, sr)

def myapp(environ, start_response):

    # Get the privs we will need
    lsd = LabelSetDesc (CAPSET=['ENV: MASTERE_CAP, MASTERE_TOK',
                                'ENV: MASTERI_CAP, MASTERI_TOK',
                                'ENV: MASTERR_CAP, MASTERR_TOK',
                                'ENV: MASTERW_CAP, MASTERW_TOK',
                                'ENV: MASTERGTAG_CAP, MASTERGTAG_TOK',
                                ], env=environ)
    lsd.acquire_capabilities ()

    #print >> sys.stderr, "endpoints %d" % len (flmo.get_endpoint_info ())
    #print >> sys.stderr, "endpoints %s" % flmo.get_endpoint_info ().prettyPrint ()
    #print >> sys.stderr, "labelset %s" % flmo.get_labelset ()

    if PROFILE:
        global e, sr
        e = environ
        sr = start_response
        cProfile.run ('launch2 ()')
        return ret
    else:
        return launch (environ, start_response)


if __name__ == '__main__':
    flmo.set_libc_interposing (False)

    from wikicode.flup.fcgi_single import WSGIServer
    WSGIServer(myapp).run()
