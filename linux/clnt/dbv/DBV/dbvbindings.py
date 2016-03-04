""" Reduction rules for interpreting sql in flume DBV
"""
import util, DBV, pg

JOIN_INNER = 1
JOIN_LEFT  = 2

join_type = {JOIN_INNER: "INNER",
             JOIN_LEFT:  "LEFT"}

CONSTRAINT_NONE    = 0
CONSTRAINT_FORKEY  = 1
CONSTRAINT_NOTNULL = 2
CONSTRAINT_UNIQUE  = 4
CONSTRAINT_PRIKEY  = CONSTRAINT_NOTNULL | CONSTRAINT_UNIQUE


class ParseNode:
    typ = 'ParseNode'
    def __init__ (self, children=()):
        self._children = children
        
    def children (self):
        return self._children

    def __str__ (self):
        return ' '.join (map (str, self._children))

    def prettyformat (self):
        return self.pp (0)

    def pp (self, depth):
        dent = ''
        for i in range (0, depth):
            dent += '  '
        s = '%s-%s (%s)\n' % (dent, self.typ, str(self))
        #s = '%s-%s\n' % (dent, self.typ)
        for c in self.children ():
            if isinstance (c, ParseNode):
                s += c.pp (depth+1)
        return s

    def get_type (cls):
        return cls.typ
    get_type = classmethod (get_type)

class StatementListNode (ParseNode):
    typ = 'StatementListNode'
    def __init__ (self, children):
        ParseNode.__init__ (self, children)
        
    def __str__ (self):
        return '; '.join (map (str, self._children))

class MyOLabelNode (ParseNode):
    typ = 'MyOLabelNode'
    def __init__ (self, l_string):
        import flume.flmos as flmo
        ParseNode.__init__ (self, [])

        assert (l_string[0] == '\'' and l_string[-1] == '\'',
                '%s string not enclosed by single quotes' % self.typ)
        self.lab = flmo.Label ()
        self.lab.fromRaw (flmo.RawData (l_string[1:-1], True))

    def __str__ (self):
        return '%s' % self.lab

class DesLSNode (ParseNode):
    typ = 'DesLSNode'
    def __init__ (self, ls_string):
        import flume.flmos as flmo
        ParseNode.__init__ (self, [])

        assert (ls_string[0] == '\'' and ls_string[-1] == '\'',
                '%s string not enclosed by single quotes' % self.typ)
        self.ls = flmo.LabelSet ()
        self.ls.fromRaw (flmo.RawData (ls_string[1:-1], True))

    def __str__ (self):
        return '%s' % self.ls

class SelectNode (ParseNode):
    typ = 'SelectNode'
    def __init__ (self, subquery, optorder_by, optlimit):
        self._subquery = subquery
        self._optorder_by = optorder_by
        self._optlimit = optlimit
        ParseNode.__init__ (self, (subquery, optorder_by, optlimit))

class SubSelectNode (ParseNode):
    typ = 'SubSelectNode'
    def __init__ (self, alldistinct, selectlist, fromclause,
                  optwhere, optgroup, opthaving, optunion):
        self._alldistinct = alldistinct
        self._selectlist = selectlist
        self._fromclause = fromclause
        self._optwhere = optwhere
        self._optgroup = optgroup
        self._opthaving = opthaving
        self._optunion = optunion
        ParseNode.__init__ (self, (alldistinct, selectlist, fromclause,
                                   optwhere, optgroup, opthaving, optunion))
        
    def __str__ (self):
        return ('SELECT %s %s %s %s %s %s %s' %
                (self._alldistinct, self._selectlist,
                 self._fromclause, self._optwhere, self._optgroup,
                 self._opthaving, self._optunion))

    def set_restrictions (self, res):
        self._optwhere.set_restrictions (res)

    def table_names (self):
        return self._fromclause.table_names ()

    def table_aliases (self):
        return self._fromclause.table_aliases ()

    def get_alias (self, name):
        return self._fromclause.get_alias (name)

class SelectStarNode (ParseNode):
    typ = 'SelectStarNode'
    def __init__ (self):
        ParseNode.__init__ (self)

    def __str__ (self):
        return '*'
    
class FromNode (ParseNode):
    typ = 'FromNode'
    def __init__ (self, trlist=None, tr1=None, tr2=None,
                  jointype=None, col1=None, col2=None):
        self._trlist = trlist
        self._tr1 = tr1
        self._tr2 = tr2
        self._jointype = jointype
        self._col1 = col1
        self._col2 = col2
        self._extra_tables = []

        if trlist:
            ParseNode.__init__ (self, [trlist])
        else:
            ParseNode.__init__ (self, (tr1, tr2, jointype, col1, col2))

    def __str__ (self):
        extra = ''
        if len (self._extra_tables) > 0:
            extra = ', %s' % (', '.join (self._extra_tables))
        
        if self._trlist:
            return 'FROM %s%s' % (self._trlist, extra)
        else:
            t = join_type[self._jointype]
            return ('FROM %s %s JOIN %s ON %s = %s' %
                    (self._tr1, t, self._tr2, self._col1, self._col2))

    def table_names (self):
        if self._trlist:
            return self._trlist.table_names ()
        else:
            return [x.table_name() for x in (self._tr1, self._tr2)]

    def table_aliases (self):
        if self._trlist:
            return self._trlist.table_aliases ()
        else:
            return [x.table_alias() for x in (self._tr1, self._tr2)]

    def get_alias (self, name):
        if self._trlist:
            return self._trlist.get_alias (name)
        else:
            a = {self._tr1.table_name() : self._tr1.table_alias(),
                 self._tr2.table_name() : self._tr2.table_alias()}
            return a[name]

    def add_tables (self, tables):
        assert self._trlist, "dont know what to do about extra tables and JOIN clauses"
        self._extra_tables.extend (tables)

class TableRefNode (ParseNode):
    typ = 'TableRefNode'
    def __init__ (self, tabname, alias):
        ParseNode.__init__ (self)
        self._tabname = tabname
        self._alias = alias

    def __str__ (self):
        if self._alias == self._tabname:
            return str(self._tabname)
        else:
            return '%s AS %s' % (self._tabname, self._alias)

    def table_name (self):
        return self._tabname
    
    def table_alias (self):
        return self._alias

class TableRefListNode (ParseNode):
    typ = 'TableRefListNode'
    def __init__ (self, tablerefs):
        # <tablerefs> is a list of TableRefNode's
        ParseNode.__init__ (self, tablerefs)

    def __str__ (self):
        return ', '.join ([str(x) for x in self._children])

    def table_names (self):
        return [str (x.table_name ()) for x in self._children]

    def table_aliases (self):
        return [str (x.table_alias ()) for x in self._children]

    def get_alias (self, tablename):
        for x in self._children:
            if x.table_name().upper() == tablename.upper():
                return x.table_alias ()
        raise KeyError, 'Could not find table %s' % tablename

class WhereNode (ParseNode):
    typ = 'WhereNode'
    def __init__ (self, search_condition = None):
        self._cond = search_condition
        self._restrictions = None
        ParseNode.__init__ (self, [search_condition])

    def __str__ (self):
        if self._restrictions is not None and self._cond is not None:
            return 'WHERE (%s) AND (%s)' % (self._restrictions, self._cond)
        elif self._restrictions is not None and self._cond is None:
            return 'WHERE (%s)' % (self._restrictions)
        elif self._cond is not None:
            return 'WHERE (%s)' % self._cond
        else:
            return ''

    def set_restrictions (self, res):
        self._restrictions = (res)

class LimitNode (ParseNode):
    typ = 'LimitNode'
    def __init__ (self, limitn):
        self._limitn = limitn
        ParseNode.__init__ (self)

    def __str__ (self):
        return 'LIMIT %d' % (self._limitn,)

class ColumnNameNode (ParseNode):
    typ = 'ColumnNameNode'
    def __init__ (self, table_name, col_id):
        self._table_name = table_name
        self._col_id = col_id
        ParseNode.__init__ (self, (table_name, col_id))

    def __str__ (self):
        if self._table_name is None:
            return str(self._col_id)
        else:
            return '%s.%s' % (self._table_name, self._col_id)

    def col_id (self):
        return self._col_id

class CreateTableNode (ParseNode):
    typ = 'CreateTableNode'
    def __init__ (self, tablename, colelts):
        self._tablename = tablename
        ParseNode.__init__ (self, [colelts])
        if not isinstance (colelts, ColumnElementsNode):
            raise AssertionError

    def __str__ (self):
        return ('CREATE TABLE %s (%s)' %
                (self._tablename, str (self._children[0])))

    def all_column_names (self):
        names = []
        for c in self._children[0].items ():
            if isinstance (c, ColumnDefinitionNode):
                names.append (c.colname())
            elif isinstance (c, ColumnConstraintNode):
                # These columns should already be in the list or else
                # you couldn't use them in a constraint definition.
                names += (c.colnames ())
            else:
                raise AssertionError, ('wrong type %s %s in column list' %
                                       (c.typ, c))
        return names

    def table_name (self):
        return self._tablename

class ColumnDefinitionNode (ParseNode):
    typ = 'ColumnDefinitionNode'
    def __init__ (self, id, datatype, optdefault, optcolconstraints):
        ParseNode.__init__ (self, (id, datatype, optdefault,
                                   optcolconstraints))
        self._id = id
        self._datatype = datatype
        self._optdefault = optdefault
        self._optcolconstraints = optcolconstraints

    def __str__ (self):
        return ' '.join (map (str, self._children))

    def colname (self):
        return str(self._id)
    def constraints (self):
        return self._optcolconstraints.children()

class OptColumnConstraintNode (ParseNode):
    typ = 'OptColumnConstraintNode'
    def __init__ (self, constraint_type):
        ParseNode.__init__ (self)
        self._ctype = constraint_type

    def __str__ (self):
        if self._ctype == CONSTRAINT_NONE:
            return ''
        elif self._ctype == CONSTRAINT_NOTNULL:
            return 'NOT NULL'
        elif self._ctype == CONSTRAINT_UNIQUE:
            return 'UNIQUE'
        elif self._ctype == CONSTRAINT_PRIKEY:
            return 'PRIMARY KEY'
        else:
            raise AssertionError, ('unexpected constraint type %s' %
                                   self._ctype)

    def get_ctype (self):
        return self._ctype

    def set_type (self, t):
        self._ctype = t

class ColumnElementsNode (ParseNode):
    typ = 'ColumnElementsNode'
    def __init__ (self, elements=()):
        ParseNode.__init__ (self, elements)

    def __str__ (self):
        return ', '.join (map (str, self._children))

    def items (self):
        return self._children

    def add (self, colname):
        self._children.append (ParseNode(children=[colname]))

class ColumnIDsNode (ColumnElementsNode):
    typ = 'ColumnIDsNode'
    def __init__ (self, elements):
        ColumnElementsNode.__init__ (self, elements)

class ColumnConstraintNode (OptColumnConstraintNode):
    # Supports unique and primary key
    typ = 'ColumnConstraintNode'
    def __init__ (self, constraint_type, columns):
        OptColumnConstraintNode.__init__ (self, constraint_type)
        self._columns = columns
        self._children = [columns]
        self._legal_ctypes = (CONSTRAINT_UNIQUE,
                              CONSTRAINT_PRIKEY)

    def __str__ (self):
        if self._ctype not in self._legal_ctypes:
            raise AssertionError, "illegal constraint %d" % self._ctype
        s = OptColumnConstraintNode.__str__(self)
        s += '(%s)' % self._columns
        return s

    def colnames (self):
        return self._columns.items ()

    def add_column (self, colname):
        self._columns.add (colname)

class ColumnFKeyNode (ColumnConstraintNode):
    typ = 'ColumnFKeyNode'
    def __init__ (self, local_cols, remote_table, remote_cols):
        ColumnConstraintNode.__init__ (self, CONSTRAINT_FORKEY, None)
        self._children = [local_cols, remote_table, remote_cols]
        self._legal_ctypes = (CONSTRAINT_FORKEY)

    def __str__ (self):
        return ("FOREIGN KEY (%s) REFERENCES %s (%s)" %
                (self._children[0], self._children[1], self._children[2]))

    def colnames (self):
        return self._children[0].items () + self._children[2].items ()

    def table_name (self):
        return self._children[1]

    def add_local_col (self, colname):
        self._children[0].add (colname)
        
    def add_remote_col (self, colname):
        self._children[2].add (colname)

class InsertNode (ParseNode):
    typ = 'InsertNode'
    def __init__ (self, tablename, optcolids, insertspec):
        self._tablename = tablename
        self._optcolids = optcolids
        self._insertspec = insertspec
        ParseNode.__init__ (self, (tablename, optcolids, insertspec))
        self._labelids = None

    def __str__ (self):
        if (isinstance (self._insertspec, InsertValueNode) and
            self._labelids is not None):
            return ('INSERT INTO %s (slabelid, ilabelid, olabelid, %s) %s' %
                    (self._tablename, self._optcolids,
                     self._insertspec.labels_and_values (*self._labelids)))
        else:
            return ('INSERT INTO %s (%s) %s' %
                    (self._tablename, self._optcolids, self._insertspec))

    def set_labelids (self, s, i, o):
        self._labelids = (s, i, o)

    def get_insertspec (self):
        return self._insertspec

    def table_name (self):
        return self._tablename

class LiteralListNode (ColumnElementsNode):
    typ = 'LiteralListNode'
    def __init__ (self, elements):
        ColumnElementsNode.__init__ (self, elements)
    
class InsertValueNode (ParseNode):
    typ = 'InsertValueNode'
    def __init__ (self, literallist):
        ParseNode.__init__ (self, [literallist])
        self._literals = literallist

    def values (self):
        return ', '.join (map (str, self._literals.items ()))

    def __str__ (self):
        return 'VALUES ( %s )' % self.values ()

    def labels_and_values (self, s, i, o):
        return 'VALUES (%d, %d, %d, %s)' % (s, i, o, self.values ())

class InsertQueryNode (ParseNode):
    typ = 'InsertQueryNode'
    def __init__ (self, query):
        ParseNode.__init__ (self, [query])
        self._query = query

    def __str__ (self):
        return str (self._query)

class UpdateNode (ParseNode):
    typ = 'UpdateNode'
    def __init__ (self, table, assignments, optwhere):
        self._table = table
        self._assignments = assignments
        self._optwhere = optwhere
        ParseNode.__init__ (self, (table, assignments, optwhere))

    def __str__ (self):
        return ('UPDATE %s SET %s %s' %
                (self._table, self._assignments,
                 self._optwhere))

    def table_name (self):
        return self._table

    def set_restrictions (self, r):
        self._optwhere.set_restrictions (r)

class AssignmentListNode (ParseNode):
    typ = 'AssignmentListNode'
    def __init__ (self, elements):
        ParseNode.__init__ (self, elements)

    def __str__ (self):
        return ', '.join (map (str, self._children))

    def items (self):
        return self._children

    def column_names (self):
        return [a._col_id for a in self._children]

class AssignmentNode (ParseNode):
    typ = 'AssignmentNode'
    def __init__ (self, col_id, expression):
        ParseNode.__init__ (self, (col_id, expression))
        self._col_id = col_id
        self._expression = expression

    def __str__ (self):
        return '%s=%s' % (self._col_id, self._expression)

class DeleteNode (ParseNode):
    typ = 'DeleteNode'
    def __init__ (self, table, optwhere):
        ParseNode.__init__ (self, (table, optwhere))
        self._table = table
        self._optwhere = optwhere

    def __str__ (self):
        return 'DELETE FROM %s %s' % (self._table, self._optwhere)

    def table_name (self):
        return self._table

    def set_restrictions (self, r):
        self._optwhere.set_restrictions (r)

class DropNode (ParseNode):
    typ = 'DropNode'
    def __init__ (self, table):
        ParseNode.__init__ (self)
        self._table = table

    def __str__ (self):
        return 'DROP TABLE %s' % (self._table,)

    def table_name (self):
        return self._table

class CreateIndexNode (ParseNode):
    typ = 'CreateIndexNode'
    def __init__ (self, name, table, columns):
        ParseNode.__init__ (self, [name, table, columns])

    def __str__ (self):
        return ("CREATE INDEX %s ON %s (%s)" %
                (self._children[0], self._children[1], self._children[2]))

    def table_names (self):
        return (self._children[0], self._children[1])

    def colnames (self):
        return [str (c) for c in self._children[2].items ()]

class SetNode (ParseNode):
    typ = 'SetNode'
    def __init__ (self, varname, to, value):
        ParseNode.__init__ (self)
        self._varname = varname
        self._to = to
        self._value = value

    def __str__ (self):
        return 'SET %s %s %s' % (self._varname, self._to, self._value)

class ShowNode (ParseNode):
    typ = 'ShowNode'
    def __init__ (self, varname):
        ParseNode.__init__ (self)
        self._varname = varname

    def __str__ (self):
        return 'SHOW %s' % (self._varname,)

class BeginNode (ParseNode):
    typ = 'BeginNode'
    def __init__ (self):
        ParseNode.__init__ (self)
    def __str__ (self):
        return 'BEGIN'

class CommitNode (ParseNode):
    typ = 'CommitNode'
    def __init__ (self):
        ParseNode.__init__ (self)
    def __str__ (self):
        return 'COMMIT'

class AbortNode (ParseNode):
    typ = 'AbortNode'
    def __init__ (self):
        ParseNode.__init__ (self)
    def __str__ (self):
        return 'ABORT'

class SpecialCaseNode (ParseNode):
    typ = 'SpecialCaseNode'
    def __init__ (self, cmd):
        ParseNode.__init__ (self)
        self._cmd = cmd
        
    def __str__ (self):
        if self._cmd.upper() == 'gettablelist'.upper():
            return """
                   SELECT c.relname
                   FROM pg_catalog.pg_class c
                   LEFT JOIN pg_catalog.pg_namespace n
                     ON n.oid = c.relnamespace
                   WHERE c.relkind IN ('r', 'v', '')
                     AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
                     AND pg_catalog.pg_table_is_visible(c.oid)"""
        else:
            raise AssertionError, ('unknown specialcase command %s' %
                                   self._cmd)

class FilterNode (ParseNode):
    typ = 'FilterNode'
    def __init__ (self, filename):
        ParseNode.__init__ (self)
        assert (filename[0] == '\'' and filename[-1] == '\'',
                '%s string not enclosed by single quotes' % self.typ)
        self.filename = filename[1:-1]

    def __str__ (self):
        return 'FILTER %s' % (self.filename,)

class ShiftLeftNode (ParseNode):
    typ = 'ShiftLeftNode'
    def __init__ (self, l, r):
        ParseNode.__init__ (self, [l,r])
    def __str__ (self):
        return '%s << %s' % (self._children[0], self._children[1])

class ShiftRightNode (ParseNode):
    typ = 'ShiftRightNode'
    def __init__ (self, l, r):
        ParseNode.__init__ (self, [l, r])
    def __str__ (self):
        return '%s >> %s' % (self._children[0], self._children[1])

class NotEqualNode (ParseNode):
    typ = 'NotEqualNode'
    def __init__ (self, l, r):
        ParseNode.__init__ (self, [l, r])
    def __str__ (self):
        return '%s <> %s' % (self._children[0], self._children[1])

class ITagEqNode (ParseNode):
    typ = 'ITagEqNode'
    def __init__ (self, table, val):
        ParseNode.__init__ (self, [table, val])
        self.table = table
        self.val = val
    def __str__ (self):
        # t.ilabelid=l.labelid AND l.tag=v.tagvalue AND v.user_id=t.owner_id
        return ('%s.ilabelid=labelid2tag.labelid AND '
                'labelid2tag.tag=%s' % (self.table, self.val))


def elt0(list, context):
    """return first member of reduction"""
    return list[0]

def default_reduc(list, context):
    """return list of len 1 of statements"""
    return ParseNode (children=list)

def columnname2 (l, c):
    return '%s.%s' % (str (l[0]), str (l[1]))

def subselect (l, c):
    [select, alldistinct, selectlist, fromclause,
     optwhere, optgroup, opthaving, optunion] = l

    return SubSelectNode (alldistinct, selectlist, fromclause,
                          optwhere, optgroup, opthaving, optunion)

def where0 (l, c):
    return WhereNode ()

def where1 (l, c):
    return WhereNode (l[1])

def createtable (l, c):
    return CreateTableNode (l[2], l[4])

def colconstraint_unique (l, c):
    return ColumnConstraintNode (CONSTRAINT_UNIQUE, l[2])
def colconstraint_prikey (l, c):
    return ColumnConstraintNode (CONSTRAINT_PRIKEY, l[3])
def colconstraint_foreignkey (l, c):
    return ColumnFKeyNode (l[3], l[6], l[8])

def optcolconstr_notnull (l, c):
    return OptColumnConstraintNode (CONSTRAINT_NOTNULL)
def optcolconstr_prikey (l, c):
    return OptColumnConstraintNode (CONSTRAINT_PRIKEY)
def optcolconstr_unique (l, c):
    return OptColumnConstraintNode (CONSTRAINT_UNIQUE)

def coldef (l, c):
    return ColumnDefinitionNode (l[0], l[1], l[2], l[3])

def coleltid (l, c):
    return ColumnElementsNode (elements=[l[0]])
coleltconstraint = coleltid

def colelts1 (l, c):
    return ColumnElementsNode (elements=l[0].items ())

def coleltsn (l, c):
    x = l[0].items ()
    x.extend (l[2].items ())
    return ColumnElementsNode (elements=x)

def optcolids0 (l, c):
    return ColumnIDsNode ([])

def optcolids1 (l, c):
    return l[1]

def colids1 (l, c):
    return ColumnIDsNode ([l[0]])

def colidsn (l, c):
    x= l[0].items ()
    x.append (l[2])
    return ColumnIDsNode (x)

def stat1 (l, c):
    return StatementListNode ([l[0]])

def statn (l, c):
    return StatementListNode ([l[0]] + l[2].children ())

def myolabelstat (l, c):
    return MyOLabelNode (l[1])

def deslsstat (l, c):
    return DesLSNode (l[1])

def insert1 (l, c):
    return InsertNode (l[2], l[3], l[4])

def insert_values (l, c):
    return InsertValueNode (l[2])

def insert_query (l, c):
    return InsertQueryNode (l[0])

def litlist1 (l, c):
    return LiteralListNode ([l[0]])

def litlistn (l, c):
    x= l[0].items ()
    x.append (l[2])
    return LiteralListNode (x)

def selectx (l, c):
    return SelectNode (l[0], l[1], l[2])

def fromclause1 (l, c):
    return FromNode (trlist=l[1])

def fromclause2 (l, c):
    return FromNode (tr1=l[1], tr2=l[4], jointype=JOIN_LEFT,
                     col1=l[6], col2=l[8])

def fromclause3 (l, c):
    return FromNode (tr1=l[1], tr2=l[5], jointype=JOIN_LEFT,
                     col1=l[7], col2=l[9])

def fromclause4 (l, c):
    return FromNode (tr1=l[1], tr2=l[4], jointype=JOIN_INNER,
                     col1=l[6], col2=l[8])

def limit1 (l, c):
    return LimitNode (l[1])

def tr1 (l, c):
    return TableRefNode (l[0], l[0])
def tr2 (l, c):
    return TableRefNode (l[0], l[1])
def tr3 (l, c):
    return TableRefNode (l[0], l[2])

def trl1 (l, c):
    return TableRefListNode ( [l[0]] )

def trln (l, c):
    return TableRefListNode ( [l[0]] + l[2].children () )

#def trl1 (l, c):
#    return trl1as ( (l[0], None, l[0]), c)

#def trln (l, c):
#    return trlnas ( (l[0], None, l[0], None, l[2]), c)

#def trl1a (l, c):
#    return trl1as ( (l[0], None, l[1]), c)

#def trlna (l, c):
#    return trlnas ( (l[0], None, l[1], None, l[3]), c)

def columnname1 (l, c):
    return ColumnNameNode (None, l[0])

def columnname2 (l, c):
    return ColumnNameNode (l[0], l[2])

simplecolname1 = columnname1
names1 = colids1
namesn = colidsn

def selectstar (l, c):
    return SelectStarNode ()
selectsome = elt0

def update (l, c):
    return UpdateNode (l[1], l[3], l[4])

def assn1 (l, c):
    return AssignmentListNode ( [l[0]] )

def assnn (l, c):
    x = l[0].items ()
    x.append (l[2])
    return AssignmentListNode (x)

def assn (l, c):
    return AssignmentNode (l[0], l[2])

def deletefrom (l, c):
    return DeleteNode (l[2], l[3])

def droptable (l, c):
    return DropNode (l[2])

def createindex (l, c):
    return CreateIndexNode (l[2], l[4], l[6])

def set1 (l, c):
    return SetNode (l[1], 'TO', l[3])
set2 = set1

def set3 (l, c):
    return SetNode ('%s %s' % (l[1], l[2]), '', l[3])

def set4 (l, c):
    return SetNode ('%s %s %s' % (l[1], l[2], l[3]),
                    '', '%s %s' % (l[4], l[5]))
def set5 (l, c):
    return SetNode ('%s %s %s' % (l[1], l[2], l[3]),
                    '', l[4])

def show (l, c):
    return ShowNode (l[1])

def begin (l, c):
    return BeginNode ()
def commit (l, c):
    return CommitNode ()
end = commit
def abort (l, c):
    return AbortNode ()
rollback = abort

def specialcase (l, c):
    return SpecialCaseNode (l[1])

def filter (l, c):
    return FilterNode (l[1])

def expshiftl (l, c):
    return ShiftLeftNode (l[0], l[3])
termshiftl = expshiftl

def expshiftr (l, c):
    return ShiftRightNode (l[0], l[3])
termshiftr = expshiftr

def predicatene (l, c):
    return NotEqualNode (l[0], l[3])
predicatene2 = predicatene
predqne = predicatene
predqne2 = predicatene

def pred_itageq (l, c):
    return ITagEqNode (l[0], l[2])

selstat = elt0
insstat = elt0
createtablestat = elt0
droptablestat = elt0
updatestat = elt0
delstat = elt0
droptablestat = elt0
createindexstat = elt0
setstat = elt0
showstat = elt0
beginstat = elt0
commitstat = elt0
abortstat = elt0
specialcasestat = elt0
filterstat = elt0
lsstat = elt0

#### do the bindings.

# note: all reduction function defs must precede this assign
VARS = vars()

class punter:
    def __init__(self, name):
        self.name = name
    def __call__(self, list, context):
        print "punt:", self.name, list
        return list

def BindRules(sqlg):
    for name in sqlg.RuleNameToIndex.keys():
        if VARS.has_key(name):
            sqlg.Bind(name, VARS[name])
        else:
            # If we haven't defined one, just use the default rule 
            sqlg.Bind(name, default_reduc) 
    return sqlg
