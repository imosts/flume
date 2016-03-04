import exceptions, os

from DBV.dbapi import LabeledDBConn

# PostgreSQL constants
PROTOCOL_VER3   = 0x00030000
CANCEL_REQ_CODE = 0x04d2162e
SSL_REQ_CODE    = 0x04d2162f

NPROCS = 1
unixsocket_base = '/var/run/postgresql'
unixsocket_tail = '.s.PGSQL.5432'

illegal_tabnames = ['labelid2label', 'labelid2tag', 'table2labelids']
illegal_create_colnames = ['slabelid', 'ilabelid', 'olabelid', 'oid']
illegal_read_colnames = ['tableoid', 'xmin', 'cmin', 'xmax', 'cmax', 'ctid']

legal_system_tables = ['pg_type']

class SecurityViolation (exceptions.Exception):
    pass
    
class ParseError (exceptions.Exception):
    pass

class TranslationError (exceptions.Exception):
    pass

def socket_dir (i):
    return '%s%d' % (unixsocket_base, i)

def socket_name (i):
    return '%s/%s' % (socket_dir (i), unixsocket_tail)

def default_db_user_pw (env=os.environ, sockidx=0):
    user = env['USER']
    dbname = user
    pw = 'pw'
    return (dbname, user, pw, socket_name (sockidx), socket_dir (sockidx))

def parse_args_or_default (args):
    dbname, user, pw, sockname, sockdir = default_db_user_pw ()

    removeme = []
    for i in range (len (args)):
        if args[i] == '-dbname':
            dbname = args[i+1]
            removeme.extend ([i, i+1])
        elif args[i] == '-user':
            user = args[i+1]
            removeme.extend ([i, i+1])
        elif args[i] == '-pw':
            pw = args[i+1]
            removeme.extend ([i, i+1])
        elif args[i] == '-sockidx':
            sockidx = int (args[i+1])
            sockname = socket_name (sockidx)
            sockdir = socket_dir (sockidx)
            removeme.extend ([i, i+1])
    removeme.reverse ()
    for idx in removeme:
        args.pop (idx)

    return args, dbname, user, pw, sockname, sockdir
    

        

