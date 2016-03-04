import wikicode
from wikicode.db.util import DBObject, DB_LSD
from wikicode.db.user import User
from wikicode.errors import *
import DBV.dbapi as dbapi

lsd_i = DB_LSD (I=['ENV: MASTERI_CAP'],
                O=['ENV: MASTERW_CAP'],
                CAPSET=['ENV: MASTERI_CAP, MASTERI_TOK',
                        'ENV: MASTERW_CAP, MASTERW_TOK'])
class App (DBObject):

    table_desc = {
        'w5_app' : ('CREATE TABLE w5_app (id integer NOT NULL PRIMARY KEY, '
                    'user_id integer NOT NULL, '
                    'appname varchar(128) NOT NULL UNIQUE, '
                    'scriptname varchar(128) NOT NULL, '
                    'mode varchar (128) NOT NULL)',
                    lsd_i)
        }

    db_pri_table = 'w5_app'
    db_pri_key = 'appname'

    sql_get_all = ('SELECT user_id, appname, scriptname, mode, id FROM %s'
                   % (db_pri_table,))

    def __init__ (self, developer, appname, scriptname, mode, id=None):
        DBObject.__init__ (self)
        self.my_pri_key = appname
        
        self.developer = developer
        self.appname = appname
        self.scriptname = scriptname
        self.mode = mode

        if type(developer) == type (1):
            d = User.object_withid (developer)
            self.developer = d.un

    def validate_appname (self, appname):
        if not appname.isalpha ():
            raise IllegalName ("Illegal app name '%s', not alpha" % appname)

    def save_vals (self):
        devel_id = wikicode.get_uid (self.developer)
        return (('user_id', 'appname', 'scriptname', 'mode'),
                (devel_id, self.appname, self.scriptname, self.mode))
