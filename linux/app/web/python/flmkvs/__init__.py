"""
This module implements client and server libraries for the Flume
key-value storage system.
"""

from pyPgSQL import libpq

default_sockfile = '/var/run/dbsock'
default_num_workers = 10
default_table_name = 'foo'
db_ip = '18.26.4.76'
db_port = 5432
db_name = 'test'
db_user = 'yipal'
db_pw = 'pw'
max_query_size = 50

KVS_OK  = 0
KVS_ERR = 1

TYPE_STRING = 'varchar(255)'
TYPE_INT    = 'integer'

debugging = True

def debug (s):
    if debugging:
        print s

def make_conn ():
    return libpq.PQconnectdb ("hostaddr='%s' port=%d dbname=%s user=%s password=%s" %
                              (db_ip, db_port, db_name, db_user, db_pw))

def table_exists (conn, tablename):
    r = conn.query ("SELECT true FROM pg_tables WHERE tablename='%s' LIMIT 1;" % (tablename,))
    return r.ntuples > 0


