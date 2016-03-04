import asyncore, flume, os, errno, traceback, sys, socket
import flume.flmos as flmo
import medusa.logger as logger
from medusa.counter import counter
from medusa.http_server import http_server, http_channel

class flume_http_channel (http_channel):

    def __repr__ (self):
        return "<channel %d on fd %d>" % (self.counter, self.socket.fileno ())

    def close (self):
        # Call both flmo.close and socket.close to be sure.
        self.del_channel ()
        fd = self.socket.fileno()
        flmo.close (fd)
        self.socket.close ()

    def handle_error(self):                                                           
        traceback.print_exc()
        self.close()                                                                  

class flume_http_server (http_server):
    channel_class = flume_http_channel 

    def __init__ (self, path, resolver=None, logger_object=None):
        asyncore.dispatcher.__init__ (self)
        self._path = path
        self.port = 0 # make the superclass happy
        self.server_name = "XMLRPC server"
        self.count = 0

        try:
            flmo.stat_file (self._path)
            flmo.unlink (self._path)
        except OSError, e:
            if e.errno != errno.ENOENT:
                raise

        fd = flmo.unixsocket (self._path, flmo.LabelSet ())
        rc = flmo.listen (fd, 5)
        sock = socket.fromfd (fd, socket.AF_UNIX, socket.SOCK_STREAM)
        self._listenfd = sock.fileno ()
        flmo.close (fd)
        sock.setblocking (0)

        self.set_socket (sock)
        self.accepting = True
        print 'XMLRPC server listening on fd %d %d %s' % (self._listenfd,
                                                          sock.fileno (),
                                                          self._path)

        self.handlers = []

        if not logger_object:
            logger_object = logger.file_logger (sys.stdout)

        self.server_port = self.port
        self.total_clients = counter()
        self.total_requests = counter()
        self.exceptions = counter()
        self.bytes_out = counter()
        self.bytes_in  = counter()

        if not logger_object:
            logger_object = logger.file_logger (sys.stdout)

        if resolver:
            self.logger = logger.resolving_logger (resolver, logger_object)
        else:
            self.logger = logger.unresolving_logger (logger_object)

        self.log_info ('RPC server started at %s' % (self._path,))

    def readable (self):
        return self.accepting

    def accept (self):
        fd = flmo.accept (self._listenfd)
        sock = socket.fromfd (fd, socket.AF_UNIX, socket.SOCK_STREAM)
        sock.setblocking (0)
        flmo.close (fd) # Close the original FD because fromfd duplicates the fd
        #print 'accepted client #%d on fd %d %d' % (self.count, fd, sock.fileno ())
        self.count += 1
        return (sock, ('flume_socket_client', 0))
