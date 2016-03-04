"""
CGI wrapper for Django using the WSGI protocol

Code copy/pasted from PEP-0333 and then tweaked to serve django.
http://www.python.org/dev/peps/pep-0333/#the-server-gateway-side

This Script is from: http://code.djangoproject.com/ticket/2407

Copy this script do django/core/servers/cgi.py
"""

import os, sys 
import django.core.handlers.wsgi

def runcgi():
    environ                      = dict(os.environ.items())

    # Django needs a PATH_INFO which includes the SCRIPT_NAME
    # See http://code.djangoproject.com/ticket/285
    # You need to edit urls.py to include the path:
    #
    # Example:
    # urlpatterns = patterns(
    #    '',
    #    (r'^cgi-bin/django/admin/', include('django.contrib.admin.urls')),
    #    )

    #sys.stderr.write ("FOO %s\n" % environ['SCRIPT_NAME'])
    
    environ['PATH_INFO']         = "%s%s" % (environ['SCRIPT_NAME'], environ.get('PATH_INFO', ""))
    
    environ['wsgi.input']        = sys.stdin
    environ['wsgi.errors']       = sys.stderr
    environ['wsgi.version']      = (1,0)
    environ['wsgi.multithread']  = False
    environ['wsgi.multiprocess'] = True
    environ['wsgi.run_once']     = True

    application = django.core.handlers.wsgi.WSGIHandler()
    
    if environ.get('HTTPS','off') in ('on','1'):
        environ['wsgi.url_scheme'] = 'https'
    else:
        environ['wsgi.url_scheme'] = 'http'
    
    headers_set  = []
    headers_sent = []

    toclient=sys.stdout
    sys.stdout=sys.stderr # print should go to stderr (logfile)
    
    def write(data):
        if not headers_set:
             raise AssertionError("write() before start_response()")
        
        elif not headers_sent:
             # Before the first output, send the stored headers
             status, response_headers = headers_sent[:] = headers_set
             toclient.write('Status: %s\r\n' % status)
             for header in response_headers:
                 toclient.write('%s: %s\r\n' % header)
             toclient.write('\r\n')
        toclient.write(data)
        toclient.flush()
        
    def start_response(status,response_headers,exc_info=None):
        if exc_info:
            try:
                if headers_sent:
                    # Re-raise original exception if headers sent
                    raise exc_info[0], exc_info[1], exc_info[2]
            finally:
                exc_info = None     # avoid dangling circular ref
        elif headers_set:
            raise AssertionError("Headers already set!")
        
        headers_set[:] = [status,response_headers]
        return write
    
    result = application(environ, start_response)
    try:
        for data in result:
            if data:    # don't send headers until body appears
                write(data)
        if not headers_sent:
            write('')   # send headers now if body was empty
    finally:
        if hasattr(result,'close'):
            result.close()
