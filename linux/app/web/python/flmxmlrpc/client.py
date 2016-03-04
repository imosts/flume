import socket, xmlrpclib
import flume.flmos as flmo
from httplib import HTTP, HTTPConnection
from xmlrpclib import _Method

# Extend Client Classes
# Look in /usr/lib/python2.5/xmlrpclib.py for ancestor code.
class _FlumeStreamHTTPConnection (HTTPConnection):
    def __init__ (self, path, strict=None):
        HTTPConnection.__init__ (self, "localhost", None, strict)
        self._path = path

    def connect (self):
        # Flume socket calls
        fd = flmo.unixsocket_connect (self._path)
        self.sock = socket.fromfd (fd, socket.AF_UNIX, socket.SOCK_STREAM)
        flmo.close (fd)

class _FlumeStreamHTTP (HTTP):
    _connection_class = _FlumeStreamHTTPConnection
        
    def __init__ (self, path, strict=None):
        self._setup (self._connection_class (path, strict))

class _FlumeStreamTransport (xmlrpclib.Transport):
    def __init__ (self, path, use_datetime=0):
        self._use_datetime = use_datetime
        self._path = path
        
    def make_connection (self, host):
        return _FlumeStreamHTTP (self._path)

class ServerProxy (xmlrpclib.ServerProxy):
    def __init__ (self, path, encoding=None, verbose=0,
                  allow_none=0, use_datetime=0):

        # Call this just to set '__' private variables since xmlrpclib
        # tries to be clever with __getattr__ and RPC function names.
        xmlrpclib.ServerProxy.__init__ (self, 'http://unixsocket',
                                        transport=_FlumeStreamTransport(path, use_datetime))
