"""
PostgreSQL database backend for Django.

Requires psycopg 2: http://initd.org/projects/psycopg2
"""
import flume
import flume.flmos as flmo
from DBV.dbapi import get_labeled_conn, commit_all_conns, rollback_all_conns, close_all_conns

from django.db.backends import util
try:
    import psycopg2 as Database
except ImportError, e:
    from django.core.exceptions import ImproperlyConfigured
    raise ImproperlyConfigured, "Error loading psycopg2 module: %s" % e

DatabaseError = Database.DatabaseError

try:
    # Only exists in Python 2.4+
    from threading import local
except ImportError:
    # Import copy of _thread_local.py from Python 2.4
    from django.utils._threading_local import local

postgres_version = None

class DatabaseWrapper(local):
    def __init__(self, **kwargs):
        self.queries = []
        self.options = kwargs

    def cursor(self, epls=None, desls=None):
        from django.conf import settings
        conn = get_labeled_conn (epls, desls)
        cursor = conn.cursor ()

        if conn.is_new ():
            conn.set_isolation_level(1)
            cursor.tzinfo_factory = None

        if settings.DEBUG:
            return util.CursorDebugWrapper(cursor, self)
        return cursor

    def _commit(self):
        commit_all_conns ()
        
    def _rollback(self):
        rollback_all_conns ()
        
    def close(self):
        close_all_conns ()

# XXX Postgres supports constraints.  Flipping this back to True might
# improve performance, but for now, disable it to avoid FlumeDB
# support for ALTER TABLE.
supports_constraints = False

def quote_name(name):
    if len (name.split (None, 1)) > 1:
        raise AssertionError, 'Flume DB names cannot contain whitespace'
    return name

dictfetchone = util.dictfetchone
dictfetchmany = util.dictfetchmany
dictfetchall = util.dictfetchall

def get_last_insert_id(cursor, table_name, pk_name):
    cursor.execute("SELECT CURRVAL('\"%s_%s_seq\"')" % (table_name, pk_name))
    return cursor.fetchone()[0]

def get_date_extract_sql(lookup_type, table_name):
    # lookup_type is 'year', 'month', 'day'
    # http://www.postgresql.org/docs/8.0/static/functions-datetime.html#FUNCTIONS-DATETIME-EXTRACT
    return "EXTRACT('%s' FROM %s)" % (lookup_type, table_name)

def get_date_trunc_sql(lookup_type, field_name):
    # lookup_type is 'year', 'month', 'day'
    # http://www.postgresql.org/docs/8.0/static/functions-datetime.html#FUNCTIONS-DATETIME-TRUNC
    return "DATE_TRUNC('%s', %s)" % (lookup_type, field_name)

def get_limit_offset_sql(limit, offset=None):
    sql = "LIMIT %s" % limit
    if offset and offset != 0:
        sql += " OFFSET %s" % offset
    return sql

def get_random_function_sql():
    return "RANDOM()"

def get_deferrable_sql():
    return " DEFERRABLE INITIALLY DEFERRED"

def get_fulltext_search_sql(field_name):
    raise NotImplementedError

def get_drop_foreignkey_sql():
    return "DROP CONSTRAINT"

def get_pk_default_value():
    return "DEFAULT"

def get_sql_flush(style, tables, sequences):
    """Return a list of SQL statements required to remove all data from
    all tables in the database (without actually removing the tables
    themselves) and put the database in an empty 'initial' state
    """
    if tables:
        if postgres_version and (postgres_version[0] >= 8 and postgres_version[1] >= 1):
            # Postgres 8.1+ can do 'TRUNCATE x, y, z...;'. In fact, it *has to* in order to be able to
            # truncate tables referenced by a foreign key in any other table. The result is a
            # single SQL TRUNCATE statement
            sql = ['%s %s;' % \
                    (style.SQL_KEYWORD('TRUNCATE'),
                     style.SQL_FIELD(', '.join([quote_name(table) for table in tables]))
                    )]
        else:
            sql = ['%s %s %s;' % \
                    (style.SQL_KEYWORD('DELETE'),
                     style.SQL_KEYWORD('FROM'),
                     style.SQL_FIELD(quote_name(table))
                     ) for table in tables]
                     
        # 'ALTER SEQUENCE sequence_name RESTART WITH 1;'... style SQL statements
        # to reset sequence indices
        for sequence in sequences:
            table_name = sequence['table']
            column_name = sequence['column']
            if column_name and len(column_name) > 0:
                # sequence name in this case will be <table>_<column>_seq
                sql.append("%s %s %s %s %s %s;" % \
                    (style.SQL_KEYWORD('ALTER'),
                     style.SQL_KEYWORD('SEQUENCE'),
                     style.SQL_FIELD('%s_%s_seq' % (table_name, column_name)),
                     style.SQL_KEYWORD('RESTART'),
                     style.SQL_KEYWORD('WITH'),
                     style.SQL_FIELD('1')
                     )
                )
            else:
                # sequence name in this case will be <table>_id_seq
                sql.append("%s %s %s %s %s %s;" % \
                    (style.SQL_KEYWORD('ALTER'),
                     style.SQL_KEYWORD('SEQUENCE'),
                     style.SQL_FIELD('%s_id_seq' % table_name),
                     style.SQL_KEYWORD('RESTART'),
                     style.SQL_KEYWORD('WITH'),
                     style.SQL_FIELD('1')
                     )
                )
        return sql
    else:
        return []
        
OPERATOR_MAPPING = {
    'exact': '= %s',
    'iexact': 'ILIKE %s',
    'contains': 'LIKE %s',
    'icontains': 'ILIKE %s',
    'gt': '> %s',
    'gte': '>= %s',
    'lt': '< %s',
    'lte': '<= %s',
    'startswith': 'LIKE %s',
    'endswith': 'LIKE %s',
    'istartswith': 'ILIKE %s',
    'iendswith': 'ILIKE %s',
}
