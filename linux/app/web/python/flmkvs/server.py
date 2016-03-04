import sys, asyncore, socket, flmxmlrpc.server, xmlrpclib, flmkvs, flume
from medusa.xmlrpc_handler import xmlrpc_handler
from db_worker import db_worker
from pyPgSQL import libpq
import flume.flmos as flmo

"""
 Notes:
  CREATE TABLE labelid2label (labelid serial unique, label bytea primary key unique);
  CREATE TABLE labelid2tag   (labelid integer, tag bigint, UNIQUE (labelid, tag));
  CREATE TABLE table2labelids (tablename varchar unique, s integer, i integer, o integer);
"""


def genquery_create (tablename, key_columns):
    if len (key_columns) < 0:
        raise AssertionError, 'must have at least one key column'
    
    return ("CREATE TABLE %s (slabel char(13), ilabel char(13), olabel char(13), %s, value bytea);" %
            (tablename, ', '.join (['key_%s %s' % (a[0], a[1]) for a in key_columns])))

class db_query_req:
    def __init__ (self, query, cb):
        self._query = query
        self._cb = cb

    def get_query (self):
        return self._query

    def get_cb (self):
        return self._cb

class kvs_server (xmlrpc_handler):
    """
    This class implements the RPC handlers for the kvs
    """

    def __init__(self,
                 sockfile=flmkvs.default_sockfile,
                 num_workers=flmkvs.default_num_workers,
                 table=flmkvs.default_table_name):
        self._sockfile = sockfile
        self._table = table
        self._query_req_queue = []
        self._workers = ()
        self._create_db_workers (num_workers)
        self._check_master_tables ()

    def _create_db_workers (self, num_workers):
        for i in range (num_workers):
            self._workers += (db_worker (),)

    def _check_master_tables (self):
        # Check that metadata tables exist, or create them
        conn = flmkvs.make_conn ()
        if not flmkvs.table_exists (conn, "table2labels"):
            conn.query ("CREATE TABLE table2labels (tablename varchar unique, "
                        "slabel char(13), ilabel char(13), olabel char(13));")
        if not flmkvs.table_exists (conn, flmkvs.default_table_name):
            conn.query (genquery_create (flmkvs.default_table_name,
                                         (('key', flmkvs.TYPE_STRING),)))

    def _get_free_worker (self):
        for w in self._workers:
            if w.is_free ():
                return w
        return None

    def start (self):
        hs = flmxmlrpc.server.flume_http_server(self._sockfile)
        hs.install_handler(self)
        asyncore.loop ()

    # ----- Manage sql queries and db_workers -----

    def start_query (self, dbworker, query_req):
        dbworker.execute_query (query_req,
                                lambda res : self.schedule_sql_query_cb (query_req, res))

    def schedule_sql_query (self, q, cb):
        query_req = db_query_req (q, cb)
        dbworker = self._get_free_worker ()
        if dbworker:
            self.start_query (dbworker, query_req)
        else:
            self._query_req_queue.append (query_req)

    def schedule_sql_query_cb (self, query_req1, res):
        dbworker = self._get_free_worker ()
        if not dbworker:
            raise AssertionError, 'there should be a free db_worker since we just finished a query'

        # Pop off a scheduled job and start it
        try:
            query_req2 = self._query_req_queue.pop (0)
            self.start_query (dbworker, query_req2)
        except IndexError:
            pass

        query_req1.get_cb () (res)

    def continue_request (self, data, request):
        params, method = xmlrpclib.loads (data)
        try:
            try:
                response = self.call (request, method, params)
                if response:
                    if type(response) != type(()):
                        response = (response,)
            except:
                # report exception back to server
                import traceback
                traceback.print_exc()
                response = (flmkvs.KVS_ERR, xmlrpclib.Fault (1, "%s:%s" % (sys.exc_type, sys.exc_value)))
        except:
            # internal error, report as HTTP server error
            sys.stderr.write ('Exception encountered, traceback:')
            import traceback
            traceback.print_exc()
            request.error (500)
        else:
            if response:
                self.send_response (request, response)

    def send_response (self, request, response):
        response = xmlrpclib.dumps (response, methodresponse=1)
        request['Content-Type'] = 'text/xml'
        request.push (response)
        request.done()

    # ----- RPC handlers and callbacks -----
    # RPC replies are of the form: (return_code, return_data), (return_code, error_string) or (return_code)
    # Return_code can be values like KVS_OK, KVS_ERR

    def add(self, op1, op2):
        return op1 + op2

    def sql_query (self, request, query):
        self.schedule_sql_query (query, lambda res : self.sql_query_cb (request, query, res))        
        return None

    def sql_query_cb (self, request, query, result):
        a = ()
        if result:
            for i in range (result.ntuples):
                a += (result.getvalue (i, 0), )
            self.send_response (request, ((flmkvs.KVS_OK, a),))
        else:
            self.send_response (request, ((flmkvs.KVS_ERR, 'error in sql query'),))


    def put (self, request, client_ls, key, value, desired_ls):
        """
        <desired_ls> is in a serialized string to pass through XMLRPC
        """
        desired_ls = flmo.filename2ls (desired_ls)
        if not (client_ls <= desired_ls):
            self.send_response (request, ( (flmkvs.KVS_ERR, 'desired LS too big'), ))
        # We'll also need to check the table labelset.

        q = ("INSERT INTO %s (slabel, ilabel, olabel, key_key, value) "
             "VALUES (%s, %s, %s, %s, %s);" %
             (self._table,
              desired_ls.get_S().freeze(),
              desired_ls.get_I().freeze(),
              desired_ls.get_O().freeze(), 
              libpq.PgQuoteString(key), libpq.PgQuoteString(value)))

        self.schedule_sql_query (q, lambda res : self.put_cb (request, key, value, res))
        return None

    def put_cb (self, request, key, value, result):
        rc = (flmkvs.KVS_OK,)
        if result is None:
            rc = (flmkvs.KVS_ERR, "Error 1 in put")
        elif result.resultStatus != 1:
            rc = (flmkvs.KVS_ERR, "Error 2 in put")
        elif result.resultType != libpq.RESULT_DML:
            raise AssertionError, 'return type should be DML'

        self.send_response (request, (rc,))

    def remove (self, request, client_ls, key):
        q = "DELETE FROM %s WHERE key_key=%s;" % (self._table, libpq.PgQuoteString(key))
        self.schedule_sql_query (q, lambda res : self.remove_cb (request, key, res))
        return None

    def remove_cb (self, request, key, result):
        rc = (flmkvs.KVS_OK,)
        if result is None:
            rc = (flmkvs.KVS_ERR, "Error 1 in remove")
        elif result.resultStatus != 1:
            rc = (flmkvs.KVS_ERR, "Error 2 in remove")
        elif result.resultType != libpq.RESULT_DML:
            raise AssertionError, 'return type should be DML'

        self.send_response (request, (rc,))

    def call(self, request, method, params):
        flmkvs.debug ("call method: %s, params: %s" % (method, str(params)))
        s = flmo.get_fd_label (flume.LABEL_S, request.channel.socket.fileno ())
        i = flmo.get_fd_label (flume.LABEL_I, request.channel.socket.fileno ())
        client_ls = flmo.LabelSet (S=s, I=i)

        # these are for debugging
        if method == 'add':
            return apply(self.add, params)
        elif method == 'sql_query':
            return apply (self.sql_query, (request,) + params)

        # these are for the KVS
        elif method == 'put':
            return apply (self.put, (request, client_ls) + params)
        elif method == 'remove':
            return apply (self.remove, (request, client_ls) + params)


        return "method not found: %s" % method

