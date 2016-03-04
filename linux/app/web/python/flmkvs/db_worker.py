import sys, asyncore, socket, flmkvs
from pyPgSQL import libpq

class db_worker (asyncore.dispatcher):
    def __init__ (self):
        asyncore.dispatcher.__init__ (self)
        self.debug = True
        self._query_req = None
        self._conn = flmkvs.make_conn ()
        self._conn.setnonblocking (True)

        # This wastes one FD per db_worker because one is in the
        # PQconnection object and one is in the python socket (for use
        # in the asyncore.dispatcher).
        self._pysocket = socket.fromfd (self._conn.socket,
                                        socket.AF_UNIX,
                                        socket.SOCK_STREAM)

        self.set_socket (self._pysocket)
        self._reading = False
        self._writing = False

    def execute_query (self, query_req, cb):
        if self._query_req:
            raise AssertionError, 'expected _query_req to be None'
        self._query_req = query_req
        self._cb = cb
        flmkvs.debug ('Worker %d handling query [%s]' % (self._conn.socket, query_req.get_query ()))
        self._writing = True
        self._sent_query = False

    def handle_read (self):
        # fd is ready, let's read it.
        self._conn.consumeInput ()

        # XXX Do something about PQnotifies
        # XXX (check here, or after getResult, make sure reable is true 
        #self._conn.

        if not self._conn.isBusy:
            self._reading = False
            self.finish_query ()

    def finish_query (self):
        if self._conn.isBusy:
            raise AssertionError, 'expected db connection to be non-busy'

        try:
            r = self._conn.getResult ()

            if self._conn.isBusy:
                raise AssertionError, 'multiple queries are not allowed'
            if self._conn.getResult () is not None:
                raise AssertionError, 'expected getResult to return None'
        except libpq.OperationalError:
            sys.stderr.write ('Exception encountered, traceback:')
            import traceback
            traceback.print_exc()
            r = None

        # Execute callback with result
        self._query_req = None
        self._cb (r)

    def handle_write (self):
        if not self._sent_query:
            self._conn.sendQuery (self._query_req.get_query ())
            self._sent_query = True
        else:
            if self._conn.flush () is None:
                self._writing = False
                self._reading = True


    def handle_connect (self):
        pass

    def writable (self):
        return self._writing

    def readable (self):
        return self._reading

    def is_free (self):
        return self._query_req is None

