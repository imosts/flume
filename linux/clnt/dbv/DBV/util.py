"""util.py

Utility functions for dbv
"""

import DBV, struct, DBV.dbvbindings, os

debug_level = None
def flume_debug_on (level):
    global debug_level
    if not debug_level:
        try:
            debug_level = int (os.environ['FLUME_DEBUG_DBV'])
        except KeyError:
            debug_level = 0
    return debug_level >= level
    
def flume_debug (level, s):
    if flume_debug_on (level):
        print '%s' % s

def to_hex (s):
    return ' '.join(["%02x" % ord(x) for x in s])

def to_alpha (s):
    chara = ''
    for x in s:
        if x >= ' ' and x <= '~':
            chara += x
        else:
            chara += ' '
    return chara

def is_msg_code (msg, code, length=0):
    if length > 0 and len (msg) != length:
        return False

    (l, c) = struct.unpack ("!II", msg[0:8])
    if (length == 0 or l == length) and c == code:
        return True
    else:
        return False

def is_ssl_req (msg):
    return is_msg_code (msg, DBV.SSL_REQ_CODE, 8)

def is_cancel_req (msg):
    return is_msg_code (msg, DBV.CANCEL_REQ_CODE, 16)

def is_startup3 (msg):
    return is_msg_code (msg, DBV.PROTOCOL_VER3)

def msg_len (msg, use_msg_type=True):
    # Return the number of msg bytes we need to read from the network
    # This differs from the msg length in the msg because the length
    # quoted in the msg does not include the msg_type byte.
    if len (msg) < 5:
        raise AssertionError, "used msg_len without the first 5 bytes"

    if use_msg_type:
        raw = msg[1:5]
        x = 1
    else:
        raw = msg[0:4]
        x = 0

    x += struct.unpack ("!I", raw)[0]
    return x

def msg_type (msg):
    if len (msg) < 1:
        raise AssertionError, "msg too short"
    return msg[0]

def get_query (msg):
    if len (msg) < 5:
        raise AssertionError, "msg too short"

    # condense whitespace
    q = msg[5:-1]
    q = ' '.join (q.split ())
    return q

def gen_psql_msg (type, s):
    format = '!ci%ds' % len (s)
    return struct.pack (format, type, len (s) + 4, s)

def gen_psql_errorresp (s):
    severity = 'ERROR'
    code = '42501'

    format = '!c%dsc%dsc%dsc' % (len (severity) + 1,
                                 len (code) + 1, len(s) + 1)
    payload = struct.pack (format, 'S', severity + '\0',
                           'C', code + '\0', 'M', s + '\0', '\0')
    return gen_psql_msg ('E', payload)

def gen_psql_readymsg ():
    # Currently, we dont support transactions, so we're always in the
    # 'I' (idle) state, not in a transaction.
    return gen_psql_msg ('Z', 'I')

def gen_psql_query (q):
    return gen_psql_msg ('Q', q + '\0')

def escape_lab (lab):
    import pg
    return pg.escape_bytea (lab.pack ())

def traverse (func, typ, parseroot, stoptype=None):
    # descends into parseroot and for each node of type <typ>, call
    # func on the node.  Does not recurse on node of type <stoptype>.
    if typ is None or isinstance (parseroot, typ):
        func(parseroot)

    for c in parseroot._children:
        if stoptype and isinstance (c, stoptype):
            continue
        elif isinstance (c, DBV.dbvbindings.ParseNode):
            traverse (func, typ, c, stoptype)

def table_exists (conn, tablename):
    q = ("SELECT true FROM pg_tables WHERE tablename='%s' LIMIT 1;" %
         (tablename,))
    r = conn.query (q)
    return r.ntuples () > 0

def get_nodes (tree, nodetypes, stoptype=None):
    l = []
    traverse (lambda n: l.append (n),
              nodetypes, tree, stoptype)
    return l

def get_unique_coldefs1 (l, coldef):
    for x in coldef.constraints ():


        if (isinstance (x, DBV.dbvbindings.OptColumnConstraintNode) and
            x.get_ctype () & DBV.dbvbindings.CONSTRAINT_UNIQUE):
            print "UNIQUE %s" % coldef.colname ()
            l.append (coldef)

def get_unique_coldefs (parseroot):
    """
    Find the column definitions what have a UNIQUE constraint and
    return a list of their ColumnDefinitionNode's.
    """
    l = []
    traverse (lambda n: get_unique_coldefs1 (l, n),
              DBV.dbvbindings.ColumnDefinitionNode,
              parseroot)
    return l

def get_unique_colconstraints1 (l, parseroot):
    if parseroot.get_ctype () & DBV.dbvbindings.CONSTRAINT_UNIQUE:
        l.append (parseroot)

def get_unique_colconstraints (parseroot):
    """
    Find the UNIQUE/PRIMARY KEY column constraints and return a list
    of their ColumnConstraintNode's.
    """
    l = []
    traverse (lambda n: get_unique_colconstraints1 (l, n),
              DBV.dbvbindings.ColumnConstraintNode,
              parseroot)
    return l

class ParseData (object):
    def __init__ (self, parsetree):
        self.parsetree = parsetree
        self.type_to_list = {}
        traverse (self.add_node, None, parsetree)

    def add_node (self, node):
        k = node.get_type ()
        if not self.type_to_list.has_key (k):
            self.type_to_list[k] = []
        self.type_to_list[k].append (node)

    def get_nodes (self, types):
        if type (types) not in (tuple, list, set):
            types = (types,)
        
        ret = []
        for k in [t.get_type () for t in types]:
            if self.type_to_list.has_key (k):
                ret.extend (self.type_to_list[k])
        return ret

    def get_statements (self):
        return self.parsetree.children ()
