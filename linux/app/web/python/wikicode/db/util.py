"""
Utility functions for using the DB
"""
from DBV.dbapi import get_labeled_conn
import flume, os
import flume.flmos as flmo
from wikicode.errors import *
from flume.labelsetdesc import LabelSetDesc

rand_id_tries = 20

class DBObjectIterator (object):
    def __init__ (self, cls, sql, cursor, lsd):
        self.cls = cls
        self.cursor = cursor
        self.lsd = lsd
        self.cursor.execute (sql)

    def __iter__(self):
        return self

    def next (self):
        ret = self.cursor.fetchone ()
        if not ret:
            self.close ()
            raise StopIteration
        return self.cls (*ret)

    def close (self):
        self.cursor.close ()

class DBObject (object):
    table_desc = {}
    sql_createindex = []
    db_pri_table = ''
    db_pri_key = ''
    my_pri_key = None

    def __init__ (self, env=os.environ):
        self.id = None
        self.env = env

    def key_transform (cls, k):
        return k
    key_transform = classmethod (key_transform)

    def pri_table_read_cursor (cls, cursor=None, env=os.environ):
        # If this table has read-protected data, then this method
        # should not be used in its current form because it does not
        # clear the process's O label after acquiring the privilege to
        # read.
        if not cursor:
            epls, desls, sqlprefix = cls.table_desc[cls.db_pri_table][1].get_read_labeling (env=env)
            conn = get_labeled_conn (epls, desls, env=env)
            cursor = conn.cursor ()
        return cursor
    pri_table_read_cursor = classmethod (pri_table_read_cursor)

    def create_tables (cls, env=os.environ):
        """ If database tables don't exist, create them. """

        cur = cls.pri_table_read_cursor (env=env)
        cur.execute ('SPECIALCASE gettablelist')
        ret = cur.fetchall ()
        
        existingtables = set ([x[0].lower() for x in ret])

        for tabname in (set (cls.table_desc.keys ()) - existingtables):
            sql, lsd = cls.table_desc[tabname]
            epls, desls, sqlprefix = lsd.get_create_labeling (savels=True)

            conn = get_labeled_conn (epls, desls)
            cur = conn.cursor ()
            cur.execute (sql)
            conn.close ()
            lsd.pop_labelset ()

            
        import psycopg2
        for sql in cls.sql_createindex:
            conn = get_labeled_conn ()
            cur = conn.cursor ()
            # XXX It would be better to check which indices exist as we do for tables.
            try:
                cur.execute (sql)
            except psycopg2.ProgrammingError, e: 
                pass
            conn.close ()
        
    create_tables = classmethod (create_tables)

    def objects (cls, where=None, env=os.environ):
        sql = cls.sql_get_all
        if where:
            sql = cls.sql_get_all + ' WHERE ' + where
        
        lsd = cls.table_desc[cls.db_pri_table][1]
        cursor = cls.pri_table_read_cursor (env=env)
        return DBObjectIterator (cls, sql, cursor, lsd)
    objects = classmethod(objects)

    def object_withid (cls, id, env=os.environ):
        cursor = cls.pri_table_read_cursor (env=env)
        cursor.execute (cls.sql_get_all + ' WHERE id=%d' % (id,))
        ret = cursor.fetchall ()

        if len (ret) > 1:
            raise DuplicateError ("Table %s has duplicate id %d"
                                  % (cls.db_pri_table, id))
        if len (ret) == 0:
            raise InvalidObject ("No such object with id %d"
                                 % (id,))
        return cls (*(ret[0]))
    object_withid = classmethod(object_withid)

    def object_withkey (cls, key, env=os.environ):
        cursor = cls.pri_table_read_cursor (env=env)
        cursor.execute (cls.sql_get_all + ' WHERE %s' % cls.pri_key_constraints (key))
        ret = cursor.fetchall ()

        if len (ret) > 1:
            raise DuplicateError ("Table %s has duplicate key %s"
                                  % (cls.db_pri_table, key))
        if len (ret) == 0:
            raise InvalidObject ("No such object with key %s"
                                 % (key,))
        kwargs = {'env': env}
        return cls (*(ret[0]), **kwargs)
    object_withkey = classmethod(object_withkey)

    def make_unique_id (self, cursor, tablename):
        import random
        for i in range (rand_id_tries):
            r = random.randint(1, 0x7ffffff)
            cursor.execute ("SELECT true FROM %s WHERE id=%d" % (tablename, r))
            if len (cursor.fetchall ()) == 0:
                return r
        raise Exception ("Could not find a unique random ID after %d tries" % rand_id_tries)

    def pri_key_constraints (cls, pri_key):
        pri_key = cls.key_transform (pri_key)

        assert (((type (cls.db_pri_key) == tuple and type (pri_key) == tuple) or
                 (type (cls.db_pri_key) != tuple and type (pri_key) != tuple)),
                'pri_key types must match, either both tuples, or both not')
        if type (pri_key) == tuple:
            columns = cls.db_pri_key
        else:
            pri_key = (pri_key,)
            columns = (cls.db_pri_key,)

        constraints = []
        for k, v in zip (columns, pri_key):
            if type (v) == type (1):
                constraints.append ("%s=%d" % (k, v))
            else:
                constraints.append ("%s='%s'" % (k, v))

        return ' AND '.join (constraints)
    pri_key_constraints = classmethod (pri_key_constraints)

    def exists (self, cursor=None, check_unique=True, env=None):
        if not env:
            env = self.env
        
        sql = "SELECT true FROM %s WHERE %s" % (self.db_pri_table,
                                                self.pri_key_constraints (self.my_pri_key))
        cursor = self.pri_table_read_cursor (cursor, env=env)
        cursor.execute (sql)
        ret = cursor.fetchall ()

        if check_unique and len (ret) > 1:
            raise DuplicateError ("Table %s has duplicate %s '%s'"
                                  % (self.db_pri_table, self.db_pri_key, self.my_pri_key))
        elif len (ret) >= 1:
            return True
        else:
            return False

    def get_id (self, cursor=None, env=None):
        if self.id:
            return self.id
        if not env:
            env=self.env

        if not self.exists (cursor=cursor, env=env):
            raise InvalidObject ('Object with %s = %s does not exist'
                                 % (self.db_pri_key, self.my_pri_key))

        cursor = self.pri_table_read_cursor (cursor, env=env)
        cursor.execute ("SELECT id FROM %s WHERE %s"
                        % (self.db_pri_table, self.pri_key_constraints (self.my_pri_key)))
        ret = cursor.fetchall ()

        self.id = int (ret[0][0])
        return self.id

    def save_vals (self):
        """ Should return a tuple of two tuples, first is a tuple of
        field names, and the second is a tuple of values"""
        raise NotImplementedError

    def save (self, epls=None, desls=None):
        use_default = False
        if epls is None and desls is None:
            sql, lsd = self.table_desc[self.db_pri_table]
            epls, desls, sqlprefix = lsd.get_write_labeling (savels=True)
            use_default = True

        conn = get_labeled_conn (epls, desls)
        cursor = conn.cursor ()
        if self.exists (cursor):
            cursor.execute ('ABORT')
            conn.close ()
            if use_default:
                lsd.pop_labelset ()
            raise NotImplementedError ("an object with key '%s' already exists" % (self.my_pri_key,))

        fields, _values = self.save_vals ()
        values = []
        for v in _values:
            if type (v) is int:
                values.append ('%d' % v)
            else:
                values.append ("'%s'" % v)

        myid = self.make_unique_id (cursor, self.db_pri_table)

        sql = ("INSERT INTO %s (id, " % (self.db_pri_table,))
        sql += ', '.join (fields) + ') VALUES (%d, ' % myid
        sql += ', '.join (values) + '); COMMIT'

        cursor.execute (sql)
        conn.close ()
        if use_default:
            lsd.pop_labelset ()

    def delete (self, epls=None, desls=None):
        use_default = False
        if epls is None and desls is None:
            sql, lsd = self.table_desc[self.db_pri_table]
            epls, desls, sqlprefix = lsd.get_write_labeling (savels=True)
            use_default = True

        conn = get_labeled_conn (epls, desls)
        cursor = conn.cursor ()
        cursor.execute ("DELETE FROM %s WHERE id=%d; COMMIT"
                        % (self.db_pri_table, self.get_id ()))
        conn.close ()
        if use_default:
            lsd.pop_labelset ()

class DB_LSD (LabelSetDesc):
    def __init__ (self, *args, **kwargs):
        LabelSetDesc.__init__ (self, *args, **kwargs)
    
    def _prefix (cls, ep_ls, des_ls):
        return ("DESLS '%s'; MYOLABEL '%s'; " %
                (des_ls.toRaw ().armor(), ep_ls.get_O ().toRaw ().armor ()))

    def get_write_labeling (self, savels=False, env=os.environ):
        """
        Returns (ep_ls, des_ls, sql_prefix) for saving objects
        according to this model.

        The S and I labels in ep_ls should be assigned to our EP to
        the DB connection.  The O label in ep_ls should be sent to the
        DB through the MYOLABEL command.
        """
        if savels:
            assert not self.oldls, 'weird, oldls should be None'
            self.oldls = flmo.get_labelset ()
            ls = self.oldls
        else:
            ls = flmo.get_labelset ()

        self.acquire_capabilities (env=env)
        des_ls = self.get_file_labelset (env=env)

        des_ls.set_S (des_ls.get_S () + ls.get_S ())
        #des_ls.set_I (des_ls.get_I () + ls.get_S ())

        ep_ls = des_ls.clone ()
        #ep_ls.set_O (self.get_label (flume.LABEL_O))
        
        # Only send what the capabilities we are using
        needed = des_ls.get_S () + des_ls.get_I () + des_ls.get_O ()
        needed = reduce (lambda l1, l2: l1 + l2.toCapabilities (), needed, [])
        ep_ls.set_O (flmo.Label (needed))
        
        sql_prefix = self._prefix (ep_ls, des_ls)
        return ep_ls, des_ls, sql_prefix

    def get_create_labeling (self, savels=False):
        """
        Returns (ep_ls, des_ls, sql_prefix) for creating tables with
        this labeling.
        """
        if savels:
            assert not self.oldls, 'weird, oldls should be None'
            self.oldls = flmo.get_labelset ()

        ep_ls, des_ls, sql_prefix = self.get_write_labeling ()
        ep_ls.set_S () # Prove we have empty S label during CREATE TABLE
        ep_ls.set_O ()
        
        sql_prefix = self._prefix (ep_ls, des_ls)
        return ep_ls, des_ls, sql_prefix
        
    def get_read_labeling (self, savels=False, env=os.environ):
        """
        Returns (ep_ls, des_ls, sql_prefix) for reading objects
        according to this labeling.
        """
        if savels:
            assert not self.oldls, 'weird, oldls should be None'
            self.oldls = flmo.get_labelset ()

        ep_ls = flmo.get_labelset ()
        ep_ls.set_O ()

        # if the tag is a read-protect tag, add it to our EP slabel
        # and add its capability to our O label, and get privs so the
        # EP label will be valid.
        for t in self.get_label (flume.LABEL_S, env=env):
            if (t.prefix () & (flume.HANDLE_OPT_GROUP |
                              flume.HANDLE_OPT_DEFAULT_ADD |
                              flume.HANDLE_OPT_DEFAULT_SUBTRACT |
                              flume.HANDLE_OPT_IDENTIFIER)) == 0:

                ep_ls.set_S (ep_ls.get_S() + t)
                ep_ls.set_O (ep_ls.get_O() + t.toCapabilities ())
                
        if len (ep_ls.get_O()) > 0:
            self.acquire_capabilities (env=env)

        des_ls = self.get_file_labelset (env=env)
        sql_prefix = self._prefix (ep_ls, des_ls)
        return ep_ls, des_ls, sql_prefix

