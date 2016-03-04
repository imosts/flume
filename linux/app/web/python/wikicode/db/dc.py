import wikicode
from wikicode.db.util import DBObject, DB_LSD
from wikicode.db.user import User
from wikicode.errors import *
import DBV.dbapi as dbapi

lsd = DB_LSD (I=['ENV: MASTERI_CAP'],
              O=['ENV: MASTERW_CAP'],
              CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                      'ENV: MASTERW_CAP, MASTERW_TOK'])

class DCInstance (DBObject):
    db_pri_table = 'w5_dcinstance'
    db_pri_key = ('user_id', 'dcname', 'instance')

    table_desc = {
        db_pri_table: ('CREATE TABLE %s (id integer NOT NULL PRIMARY KEY, '
                       'user_id integer NOT NULL, '
                       'devel_id integer NOT NULL, '
                       'dcname varchar(128), '
                       'instance varchar(128) )' % (db_pri_table,),
                       lsd)
        }

    sql_get_all = ('SELECT user_id, devel_id, dcname, instance, id FROM %s' % (db_pri_table,))

    def __init__ (self, uid, devel, dcname, instance, id=None):
        DBObject.__init__ (self)
        self.uid = uid
        self.devel_id = devel
        self.dcname = dcname
        self.instance = instance
        self.id = id
        self.my_pri_key = (self.uid, self.dcname, self.instance)

        if type(devel) == type ('abc'):
            d = User (devel)
            self.devel_id = d.get_id ()

    def save_vals (self):
        return (('user_id', 'devel_id', 'dcname', 'instance'),
                (self.uid, self.devel_id, self.dcname, self.instance))

class DCAssignment (DBObject):
    db_pri_table = 'w5_dcassignment'
    db_pri_key = 'tagvalue'

    table_desc = {
        db_pri_table: ('CREATE TABLE %s ('
                       'id integer NOT NULL PRIMARY KEY, '
                       'tagvalue bigint NOT NULL UNIQUE, '
                       'dcinstance_id integer NOT NULL)' % (db_pri_table,),
                       lsd)
        }
    sql_get_all = ('SELECT tagvalue, dcinstance_id, id FROM %s' % (db_pri_table,))

    def __init__ (self, tagvalue, dcinstance_id, id=None):
        DBObject.__init__ (self)
        self.tagvalue = tagvalue
        self.dcinstance_id = dcinstance_id
        self.id = id
        self.my_pri_key = self.tagvalue

    def save_vals (self):
        return (('tagvalue', 'dcinstance_id'), (self.tagvalue, self.dcinstance_id))

class DCAvailable (DBObject):
    db_pri_table = 'w5_dcavailable'
    db_pri_key = ('devel_id', 'dcname')

    table_desc = {
        db_pri_table: ('CREATE TABLE %s (id integer NOT NULL PRIMARY KEY, '
                       'devel_id integer NOT NULL, '
                       'dcname varchar(128) NOT NULL UNIQUE, '
                       'descr varchar(128))' % (db_pri_table,),
                       lsd)
        }    
    sql_get_all = ('SELECT devel_id, dcname, descr, id FROM %s' % (db_pri_table,))

    def __init__ (self, devel, dcname, descr, id=None):
        self.dcname = dcname
        self.devel_id = devel
        self.descr = descr
        self.id = id
        
        if type(devel) == type ('abc'):
            d = User.object_withkey (devel)
            self.devel_id = d.get_id ()

        self.my_pri_key = (self.devel_id, self.dcname)

    def save_vals (self):
        return (('devel_id', 'dcname', 'descr'),
                (self.devel_id, self.dcname, self.descr))
            
