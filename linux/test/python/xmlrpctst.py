import sys, os, socket
import flume.flmos as flmo
from SimpleXMLRPCServer import SimpleXMLRPCServer

def usage ():
    print '%s {client|server|medusa} [sockfile]' % sys.argv[0]
    sys.exit (1)

if len (sys.argv) < 2:
    usage ()

sockfile = '/var/run/foo2'
if len (sys.argv) > 2:
    sockfile = sys.argv[2]

# ----------------------------------------------------------------------------
if sys.argv[1] == 'medusa':

    import asyncore, socket, flmxmlrpc.server
    from medusa.xmlrpc_handler import xmlrpc_handler

    class test_xmlrpc_server(xmlrpc_handler):
        def __init__(self, host=None, port=8182):
            if host is None:
                host = socket.gethostname()

            hs = flmxmlrpc.server.flume_http_server(sockfile)
            hs.install_handler(self)

        def add(self, op1, op2):
            return op1 + op2

        def call(self, method, params):
            #print "call method: %s, params: %s" % (method, str(params))
            if method == 'add':
                return apply(self.add, params)
            return "method not found: %s" % method

    server = test_xmlrpc_server()
    asyncore.loop()


# ----------------------------------------------------------------------------
elif sys.argv[1] == 'server':
    # Extend Server Classes
    # Look in /usr/lib/python2.5/SocketServer.py for the ancestor code
    class FlumeXMLRPCServer (SimpleXMLRPCServer):
        address_family = socket.AF_UNIX
        def __init__ (self, addr):
            SimpleXMLRPCServer.__init__(self, addr, logRequests=False)
    
        def server_bind (self):
            self.listenfd = flmo.unixsocket (self.server_address, flmo.LabelSet ())
            self.socket = socket.fromfd (self.listenfd, socket.AF_UNIX, socket.SOCK_STREAM)
            flmo.close (self.listenfd)
            self.listenfd = self.socket.fileno()

        def server_activate (self):
            rc = flmo.listen (self.listenfd, 5)

        def get_request(self):
            clnt_fd = flmo.accept (self.listenfd)
            s = socket.fromfd (clnt_fd, socket.AF_UNIX, socket.SOCK_STREAM)
            flmo.close (clnt_fd)
            return (s, '')

        def handle_error (self, request, client_address):
            traceback.print_exc()

    # Create server
    server = FlumeXMLRPCServer (sockfile)
    server.register_introspection_functions ()

    # Register a function under a different name
    def adder_function(x,y):
        return x + y
    server.register_function(adder_function, 'add')

    # Run the server's main loop
    server.serve_forever()


# ----------------------------------------------------------------------------
elif sys.argv[1] == 'client':
    import flmxmlrpc.client

    if False:
        s = flmxmlrpc.client.ServerProxy (sockfile)
        for i in range (2000):
            r = s.add(2,3)
            if r != 5:
                raise AssertionError, 'got incorrect response from server'
            print 'RPC %d result is %s' % (i, r)

    if False:
        s = flmxmlrpc.client.ServerProxy (sockfile)
        for i in range (1):
            r = s.put ("foo", "foo's value")
            print 'RPC %dA result is %s' % (i, r)

            r = s.sql_query ("SELECT * FROM x;")
            print "RPC %dB result is %s" % (i, r)

    if True:
        import flmkvs.client
        kvs = flmkvs.client.kvsconnection ()

        r = kvs.put ("bla", "foo bar");
        print "put returns %s" % r

        r = kvs.remove ("bla");
        print "remove returns %s" % r
            

    print "PASS"

    # Print list of available methods
    #print s.system.listMethods()

# ----------------------------------------------------------------------------
else:
    usage ()
    
