
"""psql_proxy.py

A proxy for PostgreSQL that only supports a subset of SQL and enforces
Flume label rules.
"""
import asyncore, socket, string, pg, sys, os, errno, traceback
from flume import *
from flume.labelsetdesc import LabelSetDesc
import flume.flmos as flmo
import DBV.translator as translator
import DBV.security as security
import DBV.util as util
from DBV.util import flume_debug as dbg
from DBV.util import flume_debug_on as dbg_on
import DBV, DBV.sqlparser

interposing = True
PROFILE = False
memdebug = False
fail_on_err = False

if PROFILE:
    import time
    from flume.profile import start, total, print_delta

MSG_HDR_LEN = 5

global_parser = DBV.sqlparser.SQLParser ()

#####################################################
if memdebug:
    from guppy import hpy
    heapy = hpy ()

#####################################################

class proxy_server (asyncore.dispatcher):
    def __init__ (self, serverhost, serverport, dbname, user, pw, sockname):
        asyncore.dispatcher.__init__ (self)
        self.serverhost = serverhost
        self.serverport = serverport
        self.db_conn = self.init_db_conn (serverhost, serverport,
                                          dbname, user, pw)
        self.check_master_tables ()
        self.get_privs ()
        self.sockname = sockname

        try:
            ls = flmo.stat_file (self.sockname)
            slab, ilab = [flmo.get_label (t)
                          for t in (LABEL_S, LABEL_I)]

            flmo.set_label2 (S=ls.get_S(), I=ls.get_I())
            flmo.unlink (self.sockname)
            flmo.set_label2 (S=slab, I=ilab)
        except OSError, e:
            if e.errno != errno.ENOENT:
                raise
        self.start_listen (self.sockname)

    def get_privs (self):
        self.lsd = LabelSetDesc (I=['ENV: MASTERI_CAP'],
                                 CAPSET=['ENV: MASTERGTAG_CAP, MASTERGTAG_TOK'])
        self.lsd.acquire_capabilities ()
            
    def start_listen (self, sockfile):
        ls = self.lsd.get_file_labelset ()

        flmo.set_label2 (I=ls.get_I())
        fd = flmo.unixsocket (self.sockname, ls)
        flmo.set_label2 (I=None)

        rc = flmo.listen (fd, 5)
        sock = socket.fromfd (fd, socket.AF_UNIX, socket.SOCK_STREAM)
        self.set_socket (sock)
        self.listenfd = sock.fileno ()
        flmo.close (fd)

        slab, ilab = [flmo.get_fd_label (t, sock.fileno())
                      for t in (LABEL_S, LABEL_I)]
        if dbg_on (5): print ("DBV listening for connections on %s" % self.sockname)
        if dbg_on (5): print ("  proc   %s" % flmo.get_labelset ())
        if dbg_on (5): print ("  socket %s" % flmo.LabelSet (S=slab, I=ilab))

    def check_master_tables (self):
        if not util.table_exists (self.db_conn, 'labelid2label'):
            self.db_conn.query ('CREATE TABLE labelid2label (labelid serial unique,'
                                'label bytea primary key unique);')

            self.db_conn.query ('CREATE INDEX labelid2label_labelid_idx ON labelid2label (labelid);')
            self.db_conn.query ('CREATE INDEX labelid2label_tag_idx ON labelid2label (label);')
            self.db_conn.query ('CREATE INDEX labelid2label_labelid_tag_idx ON labelid2label (labelid, label);')


        if not util.table_exists (self.db_conn, 'labelid2tag'):
            self.db_conn.query ('CREATE TABLE labelid2tag   (labelid integer, '
                                'tag bigint, UNIQUE (labelid, tag));')

            self.db_conn.query ('CREATE INDEX labelid2tag_labelid_idx ON labelid2tag (labelid);')
            self.db_conn.query ('CREATE INDEX labelid2tag_tag_idx ON labelid2tag (tag);')
            self.db_conn.query ('CREATE INDEX labelid2tag_labelid_tag_idx ON labelid2tag (labelid, tag);')

        if not util.table_exists (self.db_conn, 'table2labelids'):
            self.db_conn.query ('CREATE TABLE table2labelids (tablename varchar unique, '
                                's integer, i integer, o integer);')

    def prof_start (self):
        if PROFILE:
            start ()
    def prof_delta (self, s):
        if PROFILE:
            print_delta (s)

    def handle_read (self):
        # Flume accept looks like a read event? How does
        # asyncore.dispatcher know the difference?
        self.prof_start ()
        fd = flmo.accept (self.listenfd)
        sock = socket.fromfd (fd, socket.AF_UNIX, socket.SOCK_STREAM)
        flmo.close (fd)
        self.prof_delta ("read1")
        if dbg_on (5):
            cli_ls = flmo.LabelSet (S=flmo.get_fd_label (LABEL_S, sock.fileno()),
                                    I=flmo.get_fd_label (LABEL_I, sock.fileno()))
            if dbg_on (5): print ("Accepted on fd %d, %s" % (sock.fileno (), cli_ls))

        self.prof_delta ("read2")
        if memdebug:
            print heapy.heap ()
            heapy.setref()

        self.prof_delta ("read3")
        s = dbvsession (sock, self.db_conn, self.serverhost, self.serverport)
        self.prof_delta ("read4")

    def handle_accept (self):
        print "proxy_server.handle_accept"
        (sock, addr) = self.accept ()
        if dbg_on (5): print ("Accepted connection from %s:%s" % (addr[0], addr[1]))
        s = dbvsession (sock, self.db_conn, self.serverhost, self.serverport)

    def handle_connect (self):
        pass

    def writable (self):
        return False

    def init_db_conn (self, host, port, dbname, user, pw):
        error = None
        try:
            flmo.set_libc_interposing (False)
            rc = pg.connect (dbname, host, port, user=user, passwd=pw)
            flmo.set_libc_interposing (True)
            return rc
        except TypeError, e:
            error = e
        except SyntaxError, e:
            error = e
        except pg.InternalError, e:
            error = e

        print 'error connecting to DB %s:%s, %s' % (serverhost, serverport, error)
        sys.exit (1)

    def handle_error (self):
        print 'proxy_server.error!'
        traceback.print_exc ()
        if fail_on_err:
            sys.exit (-1)

sessions = 0
class dbvsession (object):
    def __init__ (self, clisock, db_conn, srvhost, srvport):
        cli_ls = flmo.LabelSet (S=flmo.get_fd_label (LABEL_S, clisock.fileno()),
                                I=flmo.get_fd_label (LABEL_I, clisock.fileno()))
        self.clisock = clisock
        self.srvconn = srvconnection (self, db_conn, srvhost, srvport)
        self.cliconn = cliconnection (self, db_conn, clisock, cli_ls)
        self.clientdone = False
        self.serverdone = False
        self.pending_ssl = False
        if PROFILE:
            self.start = time.time ()

        self.querytimes = []
        global sessions
        sessions += 1
        self.session = sessions
        if dbg_on (25): print ("session %d begin %s" % (self.session, cli_ls))

    def forward_data (self, connection, data):
        if connection == self.srvconn:
            self.cliconn.sendmsg (data)
        else:
            self.srvconn.sendmsg (data)

    def forward_close (self, connection):
        if connection == self.srvconn:
            self.cliconn.close_afterflush ()
        else:
            self.srvconn.close_afterflush ()

    def connection_done (self, connection):
        if connection == self.srvconn:
            self.serverdone = True
        else:
            self.clientdone = True

        if self.serverdone and self.clientdone:

            #global sessions
            #sessions -= 1

            self.srvconn = None
            self.cliconn = None
            if PROFILE:
                diff = time.time() - self.start
                print 'Connection total %s' % diff
                if diff > 0:
                    if dbg_on (25): print ("session %d Queries (%d) total %f:" % (self.session, len (self.querytimes), diff))
                    total_parse = 0
                    for t, q, tq, ttrans in self.querytimes:
                         
                         if dbg_on (25): print ("session %d %f %f" % (self.session, t, ttrans))
                         if dbg_on (25): print ("session %d orig  %s" % (self.session, q))
                         if dbg_on (25): print ("session %d trans %s" % (self.session, tq))
                         total_parse += t
                    if dbg_on (25): print ("session %d total parse %f" % (self.session, total_parse))

            if dbg_on (25): print ("session %d end" % (self.session, ))
            del (self)

class connection (asyncore.dispatcher):
    def __init__ (self, db_conn, dbvsession, sock=None):
        asyncore.dispatcher.__init__ (self, sock)
        self._dbvsession = dbvsession
        self._sock = sock
        self._rbuf = ''
        self._wbuf = ''
        self._close_afterflush = False
        self._db_conn = db_conn
        self.prof_start ()

    def prof_start (self):
        if PROFILE:
            start ()
    def prof_delta (self, s):
        if PROFILE:
            print_delta (s)

    def sendmsg (self, msg):
        self._wbuf += msg

    def writable (self):
        return len (self._wbuf) > 0 or self._close_afterflush

    def handle_write (self):
        self.prof_delta ('handle_write')
        if len (self._wbuf) > 0:
            sent = self.send (self._wbuf)
            if dbg_on (50): print ('Sent %d bytes: %s ' % (sent, util.to_hex (self._wbuf[0:sent])))
            if dbg_on (50): print ('Sent %d bytes: %s ' % (sent, util.to_alpha(self._wbuf[0:sent])))
            self._wbuf = self._wbuf[sent:]

        if len (self._wbuf) == 0 and self._close_afterflush:
            self._dbvsession.forward_close (self)
            self._dbvsession.connection_done (self)
            self.close ()

    def handle_close (self):
        self._close_afterflush = True

    def close_afterflush (self):
        self._close_afterflush = True

    def handle_connect (self):
        print "connection.handle_connect"

    def handle_error (self):
        print 'connection.error!'
        if fail_on_err:
            sys.exit (-1)

    def read_extract_msgs (self, handle_ssl=False, use_msg_type=True):
        """ Read data off the socket, and if we have a whole msgs,
        return a list of the msgs. """
        self._rbuf += self.recv (8192)
        if dbg_on (50): print ('Got %d bytes' % len (self._rbuf))

        # One or more msgs are at the front of the rbuffer.
        # Handle each one.
        msgs = []
        while True:
            #self.prof_delta ("extract2")
            # Figure out how big the incoming msg is.
            if (handle_ssl and
                (self._dbvsession.pending_ssl and len (self._rbuf) >= 1)):
                self._dbvsession.pending_ssl = False
                current_msglen = 1
            elif len (self._rbuf) >= MSG_HDR_LEN:
                current_msglen = util.msg_len (self._rbuf, use_msg_type)
            else:
                break

            #self.prof_delta ("extract3")
            if len (self._rbuf) >= current_msglen:
                # We have a msg, so pull it off and forward it to the client.
                msg = self._rbuf[0:current_msglen]
                self._rbuf = self._rbuf[current_msglen:]
                
                if dbg_on (50): print ("Got whole msg (%d bytes)" % current_msglen)
                if dbg_on (50): print ('Server sent hex (%d): %s' % (len (msg), util.to_hex(msg)))
                if dbg_on (50): print ('Server sent alpha (%d): %s' % (len (msg), util.to_alpha(msg)))

                msgs.append (msg)
            else:
                # Break and wait for more data.
                break
        self.prof_delta ("extract4")
        return msgs

class cliconnection (connection):
    """ The connection between Client and DBV """

    def __init__ (self, dbvsession, db_conn, sock, cli_ls):
        connection.__init__ (self, db_conn, dbvsession, sock)
        self._saw_first_msg = False
        self._cli_ls = cli_ls
        self._filters = {}
        if PROFILE:
            self._total_parsetime = 0

    def __del__ (self):
        if PROFILE:
            print "total parse time %s" % (self._total_parsetime)

    def handle_read (self):
        self.prof_delta ('handle_read')
        for msg in self.read_extract_msgs (use_msg_type=self._saw_first_msg):
            self.handle_msg (msg)

    def handle_msg (self, msg):
        # Deal with the initiation msg
        if not self._saw_first_msg:
            if (util.is_ssl_req (msg) or util.is_cancel_req (msg) or util.is_startup3 (msg)):
                if not util.is_ssl_req (msg):
                    # Ignore ssl req, since we always reject SSL, we will
                    # be getting a regular StartupMsg next.
                    self._saw_first_msg = True
                else:
                    self._dbvsession.pending_ssl = True
                self._dbvsession.forward_data (self, msg)
                return
            else:
                print "Got unexpected initiation msg, killing dbvsession"
                self.handle_close()
                return

        t = util.msg_type (msg)
        if dbg_on (50): print ('msg_type is %c' % t)

        if (t == 'Q' and interposing):
            self.handle_query (msg)
            return
        elif t in ('p', 'S', 'X', 'C', 'f', 'Q'):
            self._dbvsession.forward_data (self, msg)
            return

        # Unhandled msgs
        elif t in ('B', 'E', 'F', 'D', 'H', 'P'):
            print 'Got msg type %c for unsupported queries' % t
            self.handle_close ()
            return
        else:
            print 'Unknown msg type %c, killing dbvsession' % t
            self.handle_close ()
            return

    def handle_query (self, msg):
        # check and translate query
        try:
            query = util.get_query (msg)
            if dbg_on (20): print ('Original   query msg %s' % query)

            des_ls = self._cli_ls.clone()
            real_cli_ls = self._cli_ls.clone()

            if PROFILE:
                start = time.time ()
            try:
                parsetree = global_parser.parse (query)
                parsedata = util.ParseData (parsetree)
            except Exception, e:
                traceback.print_exc(file=sys.stdout)
                raise DBV.ParseError, str (e)
            finally:
                if PROFILE:
                    parse_time = time.time () - start
                    self._total_parsetime += parse_time

            if dbg_on (30): print (parsetree.prettyformat ())

            security.check_label_statements (parsedata)

            # Read the O label from sql command and verify it
            cli_olabel = security.get_verified_cli_olabel (parsedata, self._sock.fileno ())
            real_cli_ls.set_O (cli_olabel)

            # Read desired S and I labels from SQL command
            tmpls = security.get_desired_ls (parsedata)
            if tmpls:
                des_ls = tmpls

            # Build an effective labelset which augments the real
            # cli_ls to include tags that the client could have
            # added or removed from its label if it wanted to.
            # Use the eff labelset when doing writes.  This
            # enables DBV to allow clients to connect with EP
            # labels I={} O={x+} and insert data with I={x}.
            eff_cli_ls = real_cli_ls.clone ()
            for t in (des_ls.get_I () - real_cli_ls.get_I ()):
                if set (t.toCapabilities ()) <= set (cli_olabel):
                    eff_cli_ls.set_I (eff_cli_ls.get_I () + t)

            # Read filters from the SQL command
            security.add_new_filters (parsedata, self._filters)

            if dbg_on (20): print ('  REAL CLILS %s' % real_cli_ls)
            if dbg_on (20): print ('  EFF  CLILS %s' % eff_cli_ls)
            if dbg_on (20): print ('  DESLS %s' % des_ls)

            # Do security checks, and then execute the query
            security.handle_query(parsedata, self._db_conn, real_cli_ls, eff_cli_ls, des_ls,
                                  self._filters.values ())

            c = lambda x: self._dbvsession.forward_data (self, util.gen_psql_query(x))
            if PROFILE:
                tbegin = time.time ()
            tq = translator.handle_query (parsedata, self._db_conn, c, self.sendmsg,
                                          eff_cli_ls, des_ls, self._filters.values ())
            if PROFILE:
                tend = time.time ()
                self._dbvsession.querytimes.append ((parse_time, query, tq, tend-tbegin))
                    
        except DBV.ParseError, e:
            print ('Got parse error on query [%s], %s' %
                   (query, str(e)))
            self.send_err (str(e))
        except DBV.TranslationError, e:
            print ('Got translation error on query [%s], %s' %
                   (query, str(e)))
            self.send_err (str(e))
        except Exception, e:
            print ('Got unexpected error on query [%s], %s' %
                   (query, str(e)))
            traceback.print_exc(file=sys.stdout)
            self.send_err ('Unexpected error, check DBV output')
            if fail_on_err:
                sys.exit (-1)

    def handle_write (self):
        self.prof_delta ('handle_write1')
        if dbg_on (50): print ("cliconnection.handle_write")
        connection.handle_write (self)
        self.prof_delta ('handle_write2')

    def send_err (self, s):
        self.sendmsg (DBV.util.gen_psql_errorresp (s) + DBV.util.gen_psql_readymsg ())

    def handle_connect (self):
        print "cliconnection.handle_connect"
        
    def handle_error (self):
        print 'cliconnection.error!'
        traceback.print_exc ()
        if fail_on_err:
            sys.exit (-1)


class srvconnection (connection):
    """ The connection between DBV and the DB server """

    def __init__ (self, dbvsession, db_conn, srvhost, srvport):
        connection.__init__ (self, db_conn, dbvsession)
        self._srvhost = srvhost
        self._srvport = srvport
        self._connected = False

    def sendmsg (self, msg):
        if not self._connected:
            # Keep create_socket and connect together?
            flmo.set_libc_interposing (False)
            self.create_socket (socket.AF_INET, socket.SOCK_STREAM)

            rc = self.connect ((self._srvhost, self._srvport))
            flmo.set_libc_interposing (True)
        if dbg_on (50): print ("sending data: %s" % msg)
        connection.sendmsg(self, msg)

    def handle_connect (self):
        if dbg_on (10): print ('Connected to server %s:%s' % (self._srvhost, self._srvport))
        self._connected = True

    def handle_read (self):
        self.prof_delta ('handle_read1')
        for msg in self.read_extract_msgs (handle_ssl=True):
            self._dbvsession.forward_data (self, msg)
        self.prof_delta ('handle_read2')

    def handle_error (self):
        print 'srvconnection.error!'
        traceback.print_exc ()
        if fail_on_err:
            sys.exit (-1)

def usage (args):
    print ('Usage: %s <server-host> <server-port> '
           '[-db <dbname>] [-user <user>] [-pw <pw>] [-pid <pid_file>]' % args[0])
    sys.exit(1)

def parse_args (args):
    args = args[1:]
    if len (args) < 2:
        raise ValueError
    elif not args[1].isdigit ():
        print 'server-port must be an integer'
        raise ValueError

    rhost = args.pop (0)
    rport = string.atoi (args.pop (0))
    pid_file = None

    for i in range (len (args)):
        if args[i] == '-pid':
            pid_file = args[i+1]
            args.pop (i)
            args.pop (i)
            break

    args, dbname, user, pw, sname, sdir = DBV.parse_args_or_default (args)
    if len (args) > 0:
        raise ValueError

    return (rhost, rport, pid_file, dbname, user, pw, sname)

if __name__ == '__main__':
    import psyco
    psyco.full()

    try:
        (serverhost, serverport, pid_file, dbname, user, pw, sname) = parse_args (sys.argv)
    except ValueError:
        usage (sys.argv)

    if pid_file:
        flmo.set_libc_interposing (False)
        if os.path.exists (pid_file):
            os.unlink (pid_file)
        f = open (pid_file, 'w')
        f.write ("%d\n" % (os.getpid (),));
        f.close ()
        flmo.set_libc_interposing (True)

    ps = proxy_server (serverhost, serverport, dbname, user, pw, sname)

    if PROFILE:
        import cProfile
        cProfile.run ('asyncore.loop()')
    else:
        asyncore.loop ()


