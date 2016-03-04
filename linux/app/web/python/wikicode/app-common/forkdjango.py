import flume.flmos as flmo
import flume.frksrv as frk
import sys, os, wikicode, traceback, random

def usage ():
    sys.stderr.write ("usage: %s <pipe-token>\n" % sys.argv[0])
    sys.exit (2)

class Child (frk.Child):
    def serve_test (self, args):
        # need to setup rpc proxy so gateway doesn't hang.
        if os.environ.has_key (wikicode.RPC_TAG_ENV):
            global rpc_proxy
            try:
                rpc_fd, rpc_proxy = wikicode.to_rpc_proxy (os.environ[wikicode.RPC_TAG_ENV])
            except OSError:
                pass

        sys.stdout.write ("content-type: text/html\r\n\r\n")
        sys.stdout.write ("OK, I'm here! LabelSet=%s, args=%s"
                          % (flmo.get_labelset (), args))
        return 0

    def serve (self, args):
        # Seed for each forked child, else they will all have same random numbers
        random.seed () 
        w5djangoutil.setup ()

        if is_prepare ():
            # Toolbar is notifying this app that the user is adding S tags.
            newstags = prepare_stags ()

            environ = dict (os.environ)
            environ['PATH_INFO'] = str (W5Uri (uri=prepare_uri (), trusted=False))
            request = WSGIRequest (environ)

            # Get a resolver that uses the URL configuration in settings.py
            resolver = urlresolvers.RegexURLResolver(r'^/', settings.ROOT_URLCONF)
            callback, callback_args, callback_kwargs = resolver.resolve(request.path)
            response = callback (request, *callback_args, **callback_kwargs)
            sys.stdout.write ("%s" % response)

        else:
            # Just run the app like normal
            runcgi()

    def close_fds (cls):
        import DBV.dbapi
        DBV.dbapi.close_all_conns ()
    close_fds = classmethod (close_fds) 

def main ():
    flmo.flume_debug_msg ("Fork server ls %s" % flmo.get_labelset ())

    if len (sys.argv) != 2:
        usage ()
    srv = frk.ForkServer (Child)
    srv.start (sys.argv[1])


if __name__ == "__main__":

    # Import stuff in the forkserver parent.
    import w5djangoutil
    w5djangoutil.global_setup ()

    try:
        from wikicode.prepare import is_prepare, prepare_uri, prepare_stags
        from django.conf import settings
        from django.core import urlresolvers
        from django.core.handlers.wsgi import WSGIRequest
        from django.core.servers.cgi import runcgi
        from wikicode import W5Uri

        import warnings
        import types
        import linecache
        import os
        import posixpath
        import stat
        import UserDict
        import copy_reg
        import encodings
        import codecs

        import w5djangoutil
        import wikicode
        import cgi
        import operator
        import urllib
        import string
        import re
        import sre_compile
        import sre_parse
        import strop
        import socket
        import _socket
        import _ssl
        import time
        import urlparse
        import mimetools
        import rfc822
        import tempfile
        import random
        import math
        import binascii
        import fcntl
        import cStringIO
        import sys
        import flume
        import flume_internal
        import _flume_internal
        import swig_runtime_data3
        import new
        import errno
        import flume.flmos
        import struct
        import _struct
        import wikicode.db.user
        import wikicode.db.util
        import datetime
        import DBV
        import DBV.dbapi
        import exceptions
        import wikicode.errors
        import flume.labelsetdesc
        import wikicode.util
        import asyncore
        import select
        import asynchat
        import collections
        import medusa
        import zlib
        import medusa.counter
        import Cookie
        import cPickle
        import wikicode.prepare
        import wikicode.spawn
        import psycopg2
        import decimal
        import copy
        import threading
        import traceback
        import psycopg2.tz
        import psycopg2._psycopg
        import mx
        import mx.DateTime
        import mx.DateTime.mxDateTime
        import mx.Misc
        import mx.Misc.LazyModule

        import djangotools
        import djangotools.util
        import django
        import django.core
        import djangotools.default_settings
        import django.middleware
        import django.middleware.common
        import django.contrib
        import django.contrib.sessions
        import django.contrib.sessions.middleware
        import django.contrib.sessions.models
        import django.db
        import django.db.backends
        import django.db.backends.flumedb
        import django.db.backends.flumedb.base
        import django.db.backends.util
        import django.db.models
        import django.core.validators
        import django.utils.translation
        import django.utils.functional
        import django.db.models.loading
        import django.db.models.query
        import django.db.transaction
        import django.db.models.fields
        import django.db.models.signals
        import django.oldforms
        import django.utils.html
        import django.newforms
        import django.newforms.util
        import django.newforms.widgets
        import django.newforms.fields
        import django.newforms.forms
        import django.newforms.models
        import django.utils.itercompat
        import django.utils.text
        import django.db.models.fields.generic
        import django.db.models.fields.related
        import django.db.models.related
        import django.db.models.manager
        import django.db.models.base
        import django.db.models.manipulators
        import django.db.models.options
        import django.contrib.w5
        import django.utils.cache
        import django.core.cache.backends
        import django.core.cache.backends.base
        import django.core.cache.backends.simple
        import django.contrib.auth
        import django.contrib.auth.middleware
        import django.middleware.doc
        import django.conf.urls
        import django.conf.urls.defaults
        import django.shortcuts
        import django.template
        import django.template.context
        import django.template.defaulttags
        import django.template.defaultfilters
        import django.template.loader
        import django.template.loader_tags
        import django.contrib.w5.models
        import django.contrib.w5.util
        import django.template.loaders
        import django.template.loaders.filesystem
        import django.template.loaders.app_directories
        import djangotools
        import djangotools.util
        import django.core
        import django.utils
        import django.utils.termcolors
        import django.db
        import django.conf
        import django.conf.global_settings
        import django.core.signals
        import django.dispatch.dispatcher
        import django.dispatch.saferef
        import django.dispatch.robustapply
        import django.dispatch.errors

        #flmo.flume_debug_msg ("forkdjango done importing")
    except Exception, e:
        s = traceback.format_exception(sys.exc_type,sys.exc_value, sys.exc_traceback)
        flmo.flume_debug_msg ("forkdjango error [%s]" % s)
    
    main ()
