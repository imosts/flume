"""
Implement a DB_API 2.0-like interface for labelled connections to the
db.

This automatically sets the EP on the database connection and adds the
verify O label to every query.  By default the desired_ls is set to
the database's endpoint labelset.

"""

import DBV, sys, os

PROFILE=False
if PROFILE:
    try:
        from flume.profile import start, total, print_delta
        start ()
    except ImportError:
        PROFILE = False

filters = set ()

def _connect (env=os.environ):
    # XXX Performance hacks
    if True:
        root_packages = [
            'mx.DateTime.mxDateTime.datetime',
            'mx.DateTime.mxDateTime.time',
            'mx.DateTime.mxDateTime.string',
            'mx.DateTime.mxDateTime.math',
            'mx.DateTime.mxDateTime.types',
            'mx.DateTime.datetime',
            'mx.DateTime.time',
            'mx.DateTime.string',
            'mx.DateTime.math',
            'mx.DateTime.types',
            ]
        for p in root_packages:
            sys.modules[p] = None
        
        oldpath = sys.path
        sys.path = ['/usr/lib/python2.5/site-packages',
                    '/usr/lib/python2.5/site-packages/psycopg2',
                    '/usr/lib/python2.5',
                    ]
        import psycopg2
        sys.path = oldpath
    else:
        sys.path.insert (0, '/usr/lib/python2.5/site-packages')
        sys.path.insert (0, '/usr/lib/python2.5/site-packages/psycopg2')

        print >> sys.stderr, "PATH %s" % (sys.path,)
        import psycopg2
        sys.path.pop (0)
        sys.path.pop (0)

    import flume.flmos as flmo
    orig = flmo.get_libc_interposing ()

    if not orig:
        flmo.set_libc_interposing (True)

    import random
    sockidx = random.randint (0, DBV.NPROCS-1)
    dbname, user, pw, sockname, sockdir = DBV.default_db_user_pw (env=env, sockidx=sockidx)

    try:
        conn = psycopg2.connect ('dbname=%s user=%s password=%s host=%s' %
                                 (dbname, user, pw, sockdir))
    except psycopg2.OperationalError:
        sys.stderr.write ("DB connect error with ls %s\n" % flmo.get_labelset ())
        raise

    if not orig:
        flmo.set_libc_interposing (orig)
    return conn

class CursorWrapper (object):
    def __init__ (self, cursor, epls, desls):
        self.cursor = cursor
        self.epls = epls
        self.desls = desls.clone ()

    def _prefix (self, desls):
        global filters
        return ("DESLS '%s'; MYOLABEL '%s'; %s" %
                (desls.toRaw ().armor(),
                 self.epls.get_O ().toRaw ().armor (),
                 ''.join (["FILTER '%s'; " % fn for fn in filters])))

    def execute (self, sql, params=(), desls=None):
        if not desls:
            desls = self.desls
        self.cursor.execute (self._prefix(desls) + sql, params)

    def executemany (self, sql, params, desls=None):
        if not desls:
            desls = self.desls
        self.cursor.executemany (self._prefix(desls) + sql, params)

    def fetchone (self, *args, **kwargs):
        ret = self.cursor.fetchone (*args, **kwargs)
        return ret

    def fetchmany (self, *args, **kwargs):
        ret = self.cursor.fetchmany (*args, **kwargs)
        return ret

    def fetchall (self, *args, **kwargs):
        ret = self.cursor.fetchall (*args, **kwargs)
        return ret

    def __getattr__ (self, name):
        return getattr (self.cursor, name)
        
class LabeledDBConn (object):
    def __init__ (self, epls=None, desls=None, env=os.environ):
        self.epls, self.desls = default_labels (epls, desls)
        self.env = env

        self.conn = self.real_connect ()
        self.refcount=1

    def is_new (self):
        return self.refcount == 1

    def close (self):
        self.refcount -= 1
        if self.refcount == 0:
            self.conn.close ()
            del conn_map[self.get_key ()]

    def get_key (self):
        return get_key (self.epls, self.desls)
        
    def real_connect (self):
        import flume
        import flume.flmos as flmo
        olds, oldi = [flmo.get_label(typ) for typ in (flume.LABEL_S, flume.LABEL_I)]

        flmo.set_label2 (S=self.epls.get_S(), I=self.epls.get_I())
        conn = _connect (self.env)

        cursor = conn.cursor()

        flmo.setepopt(cursor.fileno(), fix=True)
        flmo.set_label2 (S=olds, I=oldi)
        
        # Show our W capabilities to the DB
        cos = flmo.CapabilityOpSet ([flmo.CapabilityOp (cap, flume.CAPABILITY_SHOW)
                                     for cap in self.epls.get_O()])
        flmo.send_capabilities (cursor.fileno (), cos)
        cursor.close ()

        return conn

    def cursor (self, desls=None):
        if not desls:
            desls = self.desls
        return CursorWrapper (self.conn.cursor (), self.epls, desls)

    def __getattr__ (self, name):
        return getattr (self.conn, name)

    def get_labelid (self, label):
        cursor = self.cursor ()

conn_map = {}
def default_labels (epls, desls):
    import flume.flmos as flmo
    if not epls:
        epls_ret = flmo.get_labelset ()
    else:
        epls_ret = epls.clone ()
            
    if not desls:
        desls_ret = epls_ret.clone ()
    else:
        desls_ret = desls.clone ()
            
    return epls_ret, desls_ret

def get_key (epls, desls):
    k1, k2 = '', ''
    if epls:
        k1 = epls.hashkey ()
    if desls:
        k2 = desls.hashkey ()
    return '%s:%s' % (k1, k2)

def get_labeled_conn (epls=None, desls=None, env=os.environ):
    epls, desls = default_labels (epls, desls)
    key = get_key (epls, desls)

    if conn_map.has_key (key):
        conn_map[key].refcount += 1
    else:
        conn_map[key] = LabeledDBConn (epls, desls, env)
    return conn_map[key]

def all_conns ():
    return conn_map.values ()

def commit_all_conns ():
    for c in all_conns ():
        c.commit ()

def rollback_all_conns ():
    for c in all_conns ():
        c.rollback ()

def close_all_conns ():
    for c in all_conns ():
        c.close ()

    global conn_map
    conn_map = {}

def add_filters (filenames):
    global filters
    if type (filenames) not in (tuple, list):
        filenames = tuple (filenames)
    filters |= set (filenames)
        
