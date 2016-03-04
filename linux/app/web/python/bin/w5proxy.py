#!/usr/bin/env python
"""
Usage: python w5proxy.py --help
       python w5proxy.py [-p listenport] [-pid pidfile] [-loopback] [-f forceaddr[:port]]
         -p        : listen on <listenport>
         -pid      : write our pid to the <pidfile>
         -loopback : only listen on 127.0.0.1
         -f        : force all connections to <forceaddr:port>

  Env variable FLUME_DEBUG_PROXY may be
    0 = no debugging, only notices
    1 = access and error debugging
    2 = full debugging
    3 = really full debugging
"""
__version__ = "0.001 (W5 Proxy)"
__author__  =   "W5"
__credits__ = """Derived from Archiver Proxy by Aaron Swartz <http://www.aaronsw.com/>"""

import sys, os, time, string, re, random, binascii, traceback, stat
import socket, asyncore, asynchat, urlparse, mimetools, BaseHTTPServer
from md5 import md5
from errno import EWOULDBLOCK
from stat import ST_MTIME
from cStringIO import StringIO

REDIR_ILLEGAL_OUTSIDE_REQS = False
REDIR_URL = '/trusted'

DEFAULT_BINDADDR = ''
DEFAULT_PORT = 8000
SHOW_ERRORS = 1

#####################################################################

_debug_level = None
def debug_level ():
    global _debug_level
    if _debug_level is None:
        try:
            _debug_level = int (os.environ['FLUME_DEBUG_PROXY'])
        except KeyError:
            _debug_level = 0
    return _debug_level

def log(s, v=1, args=None):
    if v <= debug_level ():
        if args:
            sys.stdout.write(s % args)
        else:
            sys.stdout.write(s)

def dummylog(s, v=1, args=None):
    pass

def handle_error(self):
    if (sys.exc_type == socket.error and (sys.exc_value[0] == 32 or sys.exc_value[0] == 9)) or (
        sys.exc_type == AttributeError):
        # ignore these errors
        self.handle_close() # something is pretty broken, close it
        return
    if debug_level () > 0 or SHOW_ERRORS:
        print (time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time())),
               "An error has occurred: \r\n")
        traceback.print_exception(sys.exc_type,sys.exc_value, sys.exc_traceback)
    else:
        e = open('errors.txt','a')
        e.write(time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time())) +
                ' An error has occurred: \r\n')
        traceback.print_exception(sys.exc_type,sys.exc_value, sys.exc_traceback, file=e)
        e.write('\r\n')
        e.close()
        log('An error occurred, details are in errors.txt\n', v=0)

###############################################################################
class AsyncProxyError(StandardError): pass

###############################################################################
class AsyncHTTPProxySender(asynchat.async_chat):
    # Our connection to the Server 
    def __init__(self, receiver, id, host, port):
        asynchat.async_chat.__init__(self)
        self.receiver = receiver
        self.id = id
        self.set_terminator(None)
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        self.host = host
        self.port = port
        try:
            self.connect( (host, port) )
        except socket.error, e:
            if e[0] is EWOULDBLOCK: log("@@DanC hack"); return
            log('(%d) XXX %s\n' % (self.id, e))
            self.receiver.sender_connection_error(e)
            self.close()
            return

    def handle_connect(self):
        log('(%d) S handle_connect\n' % self.id, 3)
        try:
            self.receiver.sender_is_connected()
        except socket.error, e:
            log('(%d) OOO %s\n' % (self.id, e))
            if hasattr(self, 'receiver'):
                self.receiver.sender_connection_error(e)
            self.close()
            return
        log('(%d) sender connected\n' % self.id, 2)

    def return_error(self, e):
        log('(%d) sender got socket error: %s\n', args=(self.id, e), v=2)
        if isinstance(e, socket.error) and type(e.args) == type(()) and len(e.args) == 2:
            e = e.args[1]  # get the error string only
        self.receiver.error(503, 'Error connecting1 to <em>%s</em> on port <em>%d</em>: <b>%s</b>'
                            % (self.host, self.port, e), response=str(e))
        self.close()

    def collect_incoming_data(self, data):
        if debug_level () >= 3:
            log('==> (%d) %s\n', args=(self.id, repr(data)), v=3)
        else:
            log('==> (%d) %d bytes\n', args=(self.id, len(data)), v=2)

        self.receiver.push(data)

    def handle_close(self):
        log('(%d) sender closing\n' % self.id, v=2)
        if hasattr(self, 'receiver'):
            self.receiver.close_when_done()
            del self.receiver  # break circular reference
        self.close()

    def handle_error(self):
        asynchat.async_chat.handle_error(self)

    def log(self, message):
        log('(%d) sender: %s\n', args=(self.id, message,), v=1)

    def log_info(self, message, type='info'):
        if __debug__ or type != 'info':
            log('%s: %s' % (type, message), v=0)

###############################################################################
class AsyncHTTPProxyReceiver(asynchat.async_chat):
    # Our connection to the client 
    channel_counter = [0]

    def __init__(self, server, (conn, addr), forceaddr=None):
        self.id = self.channel_counter[0]  # used during log calls
        try:
            self.channel_counter[0] = self.channel_counter[0] + 1
        except OverflowError:
            self.channel_counter[0] = 0
        asynchat.async_chat.__init__(self, conn)
        self.set_terminator('\n')
        self.server = server
        self.buffer = StringIO()

        if forceaddr:
            self.forcehost, self.forceport = self.split_netloc (forceaddr, "GET")
        else:
            self.forcehost, self.forceport = None, None

        # in the beginning there was GET...
        self.found_terminator = self.read_http_request

    def collect_incoming_data(self, data):
        self.buffer.write(data)

    def push_incoming_data_to_sender(self, data):
        if debug_level () >= 3:
            log('<== (%d) %s\n', args=(self.id, repr(data)), v=3)
        else:
            log('<== (%d) %d bytes\n', args=(self.id, len(data)), v=2)
        self.sender.push(data)

    def split_netloc (self, netloc, method):
        # find port number
        if ':' in netloc:
            h, p = string.split(netloc, ':')
            p = string.atoi(p)
        else:
            h = netloc
            if method == 'CONNECT':
                p = 443  # default SSL port
            else:
                p = 80
        return h, p

    #### to be used as a found_terminator method
    def read_http_request(self):
        self.request = self.buffer.getvalue()
        self.buffer = StringIO()

        log('%s - %s\n', args=(time.ctime(time.time()), self.request), v=1)

        # client-originated shutdown hack:
        if string.strip(self.request) == 'quit':
            log('External quit command received.\n')
            # On pre python 2.0 this will raise a NameError,
            # but asyncore will handle it well.  On 2.0, it
            # will cause asyncore to exit.
            raise asyncore.ExitNow

        try:
            self.method, self.url, self.protocol = string.split(self.request)
            self.method = string.upper(self.method)
        except:
            self.error(400, "Can't parse request")
        if not self.url:
            self.error(400, "Empty URL")
        
        if not (self.url.startswith ('http://') or self.url.startswith ('https://')):
            self.error (400, "Got regular HTTP request for %s, "
                        "expected proxy request with fully qualified URI."
                        % self.url)

        if self.method not in ['CONNECT', 'GET', 'HEAD', 'POST', 'PUT']:
            self.error(501, "Unknown request method (%s)" % self.method)

        if self.method == 'CONNECT':
            self.netloc = self.url
            self.scheme = 'https'
            self.path = ''
            params, query, fragment = '', '', ''
            try:
                self.host, self.port = self.split_netloc (self.netloc, self.method)
            except Exception, e:
                print "e1 %s" % e
        else:
            if self.url[0] == '/':
                self.path = self.url
            else:
                # split url into site and path
                self.scheme, self.netloc, self.path, params, query, fragment = urlparse.urlparse(self.url)
                if string.lower(self.scheme) != 'http':
                    self.error(501, "Unknown request scheme (%s)" % self.url) #, self.scheme)

                self.host, self.port = self.split_netloc (self.netloc, self.method)
                self.path = urlparse.urlunparse(('', '', self.path, params, query, fragment))

        self.rawheaders = StringIO()  # a "file" to read the headers into for mimetools.Message
        self.found_terminator = self.read_http_headers

    def gen_connect_resp (self):
        # Send "Connection established" to client
        return ("HTTP/1.0 200 Connection established\r\n"
                "Proxy-agent: Netscape-Proxy/1.1\r\n\r\n")

    def get_zone_suffix (self, forcehost):
        return '.' + os.environ.get ("BFLOW_ZONE_SUFFIX", forcehost.rsplit ('.', 1)[0])

    def read_http_headers(self):
        #### to be used as a found_terminator method
        header = self.buffer.getvalue()
        self.buffer = StringIO()
        if header and header[0] != '\r':
            self.rawheaders.write(header)
            self.rawheaders.write('\n')
        else:
            # all headers have been read, process them
            self.rawheaders.seek(0)
            self.mimeheaders = mimetools.Message(self.rawheaders)
            if ((self.method == 'POST' or self.method == 'PUT') and
                not self.mimeheaders.has_key('content-length')):
                self.error(400, "Missing Content-Length for %s method" % self.method)
            self.length = int(self.mimeheaders.get('content-length', 0))
            del self.mimeheaders['accept-encoding']
            del self.mimeheaders['proxy-connection']

            # Decide whether to forward, redirect, or proxy the HTTP request
            match_w5server = (self.host.endswith (self.forcehost) and self.port == self.forceport)
            match_w5suffix = self.host.endswith (self.get_zone_suffix (self.forcehost))

            referrer_ls = _LabelSet (s=self.mimeheaders.get ('X-referrer-slabel', '[]'),
                                     i=self.mimeheaders.get ('X-referrer-ilabel', '[]'),
                                     o=self.mimeheaders.get ('X-referrer-olabel', '[]'))
            
            if (match_w5server or match_w5suffix):
                # Change host to W5 server if necessary
                if self.forcehost or match_w5suffix:
                    h, p = self.forcehost, self.forceport
                else:
                    assert not match_w5suffix, "Matched W5 suffix, but I have no forcehost!"
                    h, p = self.host, self.port

                # create a sender connection to the next hop
                self.sender = AsyncHTTPProxySender(self, self.id, h, p)
                if self.method == "CONNECT":
                    self.push (self.gen_connect_resp ())

                # send the request to the sender (this is its own method so that the sender can trigger
                # it again should its connection fail and it needs to redirect us to another site)
                self.push_request_to_sender()

            elif referrer_ls.canTalkOutside ():
                self.sender = AsyncHTTPProxySender(self, self.id, self.host, self.port)
                if self.method == "CONNECT":
                    self.push (self.gen_connect_resp ())

                # send the request to the sender (this is its own method so that the sender can trigger
                # it again should its connection fail and it needs to redirect us to another site)
                self.push_request_to_sender()

            else:                
                if REDIR_ILLEGAL_OUTSIDE_REQS:
                    # if the user sent a bogus hostname, redirect him to W5 server.
                    self.push ('HTTP/1.0 302\r\n'
                               'Content-Type: text/html; charset=utf-8\r\n'
                               'Location: http://%s:%d/%s\r\n\r\n' % (self.forcehost, self.forceport, REDIR_URL))
                    self.close ()
                else:
                    # Just tell the user he can't visit an outside page
                    # from a tainted, untrusted page.
                    self.error(403, 'You may not access that page from a tainted, untrusted page')

	
    def push_request_to_sender(self):
        # If in SSL "CONNECT" mode, dont send the normal request, just proxy data.
        if self.method != "CONNECT":
            request = ('%s %s HTTP/1.0\r\n%s\r\n' %
                       (self.method, self.path, string.join(self.mimeheaders.headers, '')))

            log('(%d) sending request to server:\n' % self.id, v=2)
            log(request, v=2)

            # send the request and headers on through to the next hop
            self.sender.push(request)

        # no more formatted IO, just pass any remaining data through
        self.set_terminator(None)

        # buffer up incoming data until the sender is ready to accept it
        self.buffer = StringIO()

    def sender_is_connected(self):
        """
        The sender calls this to tell us when it is ready for more data
        """
        log('(%d) R sender_is_connected()\n' % self.id, v=3)
        # sender gave us the OK, give it our buffered data and any future data we receive
        self.push_incoming_data_to_sender(self.buffer.getvalue())
        self.buffer = None
        self.collect_incoming_data = self.push_incoming_data_to_sender
	
    def sender_connection_error(self, e):
        log('(%d) R sender_connection_error(%s) for %s:%s\n' % (self.id, e, self.host, self.port), v=2)
        if isinstance(e, socket.error) and type(e.args) == type(()) and len(e.args) == 2:
            e = e.args[1]  # get the error string only
        self.error(503, 'Error connecting2 to <em>%s</em> on port <em>%d</em>: <b>%s</b>'
                   % (self.host, self.port, e), response=str(e))

    def handle_close(self):
        log('(%d) receiver closing\n' % self.id, v=2)
        if hasattr(self, 'sender'):
            # self.sender.close() should be fine except for PUT requests?
            self.sender.close_when_done()
            del self.sender  # break circular reference
        self.close()
	
    def show_response(self, code, body, title=None, response=None):
        if not response:
            response = BaseHTTPServer.BaseHTTPRequestHandler.responses[code][0]
        if not title:
            title = str(code) + ' ' + response
        self.push("HTTP/1.0 %s %s\r\n" % (code, response))
        self.push("Server: W5Proxy\r\n")
        self.push("Content-type: text/html\r\n")
        self.push("\r\n")
        out = "<html><head>\n<title>" + title + "</title>\n</head>\n"
        out += '<body><h1>' + title +'</h1>\n'
        out += body 
        out += ('<hr />\n<address><a href="%s">W5Proxy %s</a></address>'
                % (self.server.oururi, __version__))
        out += '\n</body>\n</html>'
        i = 0
        for j in range(len(out) / 512):
            self.push(out[i:i+512]) # push only 512 characters at a time
            i += 512
        self.push(out[i:]) # push out the rest

    def error(self, code, body, response=None):
        self.show_response(code, body, response=response)
        if hasattr(self, 'sender'):
            self.sender.handle_close()
            del self.sender  # break circular reference
        self.close()
        # asyncore.poll() catches this	(XXX shouldn't need this?)
        #raise AsyncProxyError, (code, body)

    def handle_error(self):
        asynchat.async_chat.handle_error(self)

    def log(self, message):
        log('(%d) receiver: %s\n', args=(self.id, message,), v=1)

    def log_info (self, message, type='info'):
        if __debug__ or type != 'info':
            log('%s: %s' % (type, message))


###############################################################################
class AsyncHTTPProxyServer(asyncore.dispatcher):
	def __init__(self, bindaddr, port, forceaddr=None):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.ouraddr = (bindaddr, port)
		self.oururi = "http://%s:%d/" % self.ouraddr
		log('Starting proxy at %s\n' % self.oururi, 0)
		self.bind(self.ouraddr)
		self.listen(5)
                self.forceaddr = forceaddr

	def handle_accept(self):
		AsyncHTTPProxyReceiver(self, self.accept(), self.forceaddr)

	def log(self, message):
		log('server: %s\n', args=(message,), v=1)

	def handle_error(self):
            asyncore.dispatcher.handle_error()

class _Label (object):
    def __init__ (self, s):
        tags_str = s.strip ().strip ('[]').split (',')
        self.tags = [int (t, 16) for t in tags_str if t != '']

    def length (self):
        return len (self.tags)

    def __str__ (self):
        return "[%s]" % (','.join (["0x%x" % t for t in self.tags]),)

class _LabelSet (object):
    def __init__ (self, s, i, o):
        for lab_str, vname in ((s, 's'), (i, 'i'), (o, 'o')):
            setattr (self, vname, _Label (lab_str))

    def canTalkOutside (self):
        # YIPAL: This is where we can make declassification decisions.
        return (self.s.length () == 0 and self.i.length () == 0)

    def __str__ (self):
        return "S=%s I=%s O=%s" % (self.s, self.i, self.o)

if __name__ == '__main__':
    bindaddr = DEFAULT_BINDADDR
    port = DEFAULT_PORT
    forceaddr = None

    args = list (sys.argv[1:])
    while (len (args) > 0):
        arg = args.pop (0)
        if arg == '-p':
            port = int (args.pop (0))
        elif arg == '-pid':
            PIDFILE = args.pop (0)
            f = open (PIDFILE, 'wtc')
            f.write ('%d\n' % os.getpid ())
            f.close ()
        elif arg == '-loopback':
            bindaddr = '127.0.0.1'
        elif arg == '-f':
            forceaddr = args.pop (0)
        else:
            print __doc__ % {'PORT':port}
            print
            print "Version: " + __version__
            raise SystemExit

    ps = AsyncHTTPProxyServer(bindaddr, port, forceaddr)
    log("Starting service...\n")
    asyncore.loop()
