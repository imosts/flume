import util, pg
from dbvbindings import *

legal_set_variables = ('client_encoding', 'datestyle', 'seed', 'server_encoding',
                       'time zone', 'transaction isolation level')
legal_show_variables = ('client_encoding', 'default_transaction_isolation')

lab_statement_types = ('MyOLabelNode', 'DesLSNode')

# Check table labels when a client tries to modify/drop a table (not
# including the rows themselves).  (Should equal True)
CHECK_TABLE_LABELS = True

# Check table labels when a client inserts/updates/deletes a row from
# a table.  We disable this because the row label takes care of the
# securty checks.  If we leave it on, then a client with S={x} cannot
# insert a row into a table with S={}, even if the row has S={x}.
CHECK_TABLE_LABELS_ON_ROW = False

def check_tablenames (parsedata):
    names = []
    for node in parsedata.get_nodes ((CreateTableNode, InsertNode, UpdateNode, DropNode)):
        names.append (node.table_name ())

    for node in parsedata.get_nodes (TableRefListNode):
        # This handles SubSelectNodes
        names.extend (node.table_names () + node.table_aliases ())

    for node in parsedata.get_nodes (CreateIndexNode):
        names.extend (node.table_names ())

    for name in names:
        if str(name).upper () in [s.upper () for s in DBV.illegal_tabnames]:
            raise DBV.SecurityViolation, 'Table name \"%s\" is prohibited' % name

def check_colnames (parsedata):
    for node in parsedata.get_nodes (CreateTableNode):
        # Creating columns
        for c in node.all_column_names ():
            if str(c).upper () in [s.upper ()
                                   for s in (DBV.illegal_create_colnames +
                                             DBV.illegal_read_colnames)]:
                raise DBV.SecurityViolation, 'Cannot create column \"%s\"' % c

    for node in parsedata.get_nodes (CreateIndexNode):
        for c in node.colnames ():
            if str(c).upper () in [s.upper ()
                                   for s in (DBV.illegal_create_colnames +
                                             DBV.illegal_read_colnames)]:
                raise DBV.SecurityViolation, 'Cannot create column \"%s\"' % c

    for node in parsedata.get_nodes (ColumnNameNode):
        # Reading from columns
        if str(node.col_id ()).upper () in [s.upper ()
                                            for s in DBV.illegal_read_colnames]:
            raise DBV.SecurityViolation, 'Column name \"%s\" is unreadable' % node.col_id ()

    for node in parsedata.get_nodes (AssignmentListNode):
        # Modifying columns
        for c in node.column_names ():
            if str(c).upper () in [s.upper ()
                                   for s in (DBV.illegal_create_colnames +
                                             DBV.illegal_read_colnames)]:
                raise DBV.SecurityViolation, 'Cannot update column \"%s\"' % c

def check_select_tables (db_conn, client_ls, parsedata):
    for node in parsedata.get_nodes (SubSelectNode):
        for t in node.table_names ():
            if t.lower ().startswith ('pg_'):
                # Special-case system table or view
                if t.upper () in [s.upper () for s in DBV.legal_system_tables]:
                    pass
                else:
                    raise DBV.SecurityViolation, ('Client not permitted to read from system '
                                                  'table, %s' % (t,))
            else:
                if CHECK_TABLE_LABELS_ON_ROW:
                    # Flume table
                    table_ls = get_table_labelset (db_conn, t)
                    util.flume_debug (30, '%s table_ls is %s' % (t, table_ls))

                    if not (table_ls <= client_ls):
                        raise DBV.SecurityViolation, ('Client not permitted to read from table %s, %s '
                                                      '(table) must be <= %s (client)' %
                                                      (t, table_ls, client_ls))

table_ls_cache = {}
def get_table_labelset (db_conn, tablename):
    if not table_ls_cache.has_key (tablename):

        q = ('SELECT s.label, i.label, o.label '
             '  FROM table2labelids t '
             '    INNER JOIN labelid2label s ON t.s=s.labelid'
             '    INNER JOIN labelid2label i ON t.i=i.labelid'
             '    INNER JOIN labelid2label o ON t.o=o.labelid'
             '  WHERE t.tablename=\'%s\';' % tablename)
        res = db_conn.query (q)
        if res.ntuples () == 0:
            raise AssertionError, 'Could not find labels for table %s' % tablename
        elif res.ntuples () > 1:
            raise AssertionError, 'too many labels for table %s' % tablename

        import flume.flmos as flmo
        (s, i, o) = [flmo.Label.unpack (pg.unescape_bytea (v)) for v in res.getresult ()[0]]
        table_ls_cache[tablename] = flmo.LabelSet (S=s, I=i, O=o)
    return table_ls_cache[tablename]

def handle_create (createnode, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    if len (real_client_ls.get_S ()) > 0:
        raise DBV.SecurityViolation, 'Client must have empty S when creating a table'

    # Check that the client is allowed to create a table with <desired_ls>
    if not (eff_client_ls <= desired_ls):
        raise DBV.SecurityViolation, ('Desired labelset is too permissive, %s (client) must be <= %s (table)' %
                                      (eff_client_ls, desired_ls))

    # Do we also need to check desired_ls.get_O() ?  I don't think so.

def handle_create_index (node, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    # XXX This should probably check that the I_client >= I_table 
    if len (real_client_ls.get_S ()) > 0:
        raise DBV.SecurityViolation, 'Client must have empty S when creating an index'

def handle_insert (insertnode, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    table_ls = get_table_labelset (db_conn, insertnode._tablename)
    if CHECK_TABLE_LABELS_ON_ROW:
        # Check that the client is allowed to insert into this table
        if not (eff_client_ls <= table_ls):
            raise DBV.SecurityViolation, ('Client not permitted to insert into '
                                          '%s, %s (client) must be <= %s (table)' %
                                          (insertnode._tablename, eff_client_ls, table_ls))
        
    # Check that new rows are permitted in this table (This only
    # checks S because we allow tables with I={} to have higher
    # integrity data)
    if not (table_ls.get_S () <= desired_ls.get_S ()):
        raise DBV.SecurityViolation, ('Desired S label is too permissive, %s (table) must be <= %s (row)' %
                                      (table_ls.get_S (), desired_ls.get_S ()))

    # Check that the client is allowed to insert a row with <desired_ls> (seems redundant...)
    if not (eff_client_ls <= desired_ls):
        raise DBV.SecurityViolation, ('Desired labelset is too permissive, %s (client) must be <= %s (row)' %
                                      (eff_client_ls, desired_ls))

    # Check that the client is allowed to read a row with the
    # <desired_ls>.  Without this check, an attacker with S={} could
    # learn data with S={x} by inserting data with S={x} and looking
    # for uniqueness errors from the DB, even though uniqueness
    # constraints are concatenated with the S label.
    if not (desired_ls <= eff_client_ls):
        raise DBV.SecurityViolation, ('Row labelset is too permissive, %s (row) must be <= %s (client)' %
                                      (desired_ls, eff_client_ls))
    
    # Clients are allowed to insert rows with any O label they want

def handle_select (selectnode, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    pass

def handle_update (updatenode, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    # Check that the client is allowed to update this table
    if CHECK_TABLE_LABELS_ON_ROW:
        table_ls = get_table_labelset (db_conn, updatenode._table)
        if not (eff_client_ls <= table_ls):
            raise DBV.SecurityViolation, ('Client not permitted to update '
                                          '%s, %s (client) must be <= %s (table)' %
                                          (updatenode.table_name(), eff_client_ls, table_ls))

    # XXX A user with S = {} can insert and update a table with S =
    # {foo}.  Would that leak info if somehow writers to the table
    # could prevent new inserts from succeeding?  I think this is the
    # normal resource exhaustion attack.

def handle_delete (node, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    if CHECK_TABLE_LABELS_ON_ROW:
        # Check that the client is allowed to delete from this table
        table_ls = get_table_labelset (db_conn, node._table)
        if not (eff_client_ls <= table_ls):
            raise DBV.SecurityViolation, ('Client not permitted to '
                                          'delete from %s, %s (client) '
                                          'must be <= %s (table)' %
                                          (node.table_name (),
                                           eff_client_ls, table_ls))

def handle_drop (node, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):

    # XXX This should check that the client is allowed to write to all
    # of the rows in the table, because it is deleting every row.

    if CHECK_TABLE_LABELS:
        # Check that the client is allowed to drop this table
        table_ls = get_table_labelset (db_conn, node._table)
        if not (eff_client_ls <= table_ls):
            raise DBV.SecurityViolation, ('Client not permitted to '
                                          'drop %s, %s (client) '
                                          'must be <= %s (table)' %
                                          (node.table_name (),
                                           eff_client_ls, table_ls))

def handle_set (setnode, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    if setnode._varname.upper() not in [s.upper() for s in legal_set_variables]:
        raise DBV.SecurityViolation, "No support for setting variable '%s'" % setnode._varname


def handle_show (shownode, parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters):
    if shownode._varname.upper() not in [s.upper() for s in legal_show_variables]:
        raise DBV.SecurityViolation, "No support for showing variable '%s'" % shownode._varname

def handle_ok (*args):
    pass

def check_whole_list (parsedata):
    # If there are any create nodes, make sure the statement list is
    # only a single create node.  Flumedb doesn't support multiple
    # statements with create nodes, unless it is a LS statement.

    create = False
    non_create_non_ls = False
    for node in parsedata.get_statements ():
        if not isinstance (node, (MyOLabelNode, DesLSNode, CreateTableNode, FilterNode)):
            non_create_non_ls = True
        if isinstance (node, CreateTableNode):
            create = True
    if create and non_create_non_ls:
        raise DBV.SecurityViolation, ('Illegal query, create node cannot share '
                                      'with other statements, unless it is a '
                                      'MyOLabelNode')

def handle_query (parsedata, db_conn, real_client_ls, eff_client_ls, desired_ls, filters=[]):
    check_whole_list (parsedata)
    check_tablenames (parsedata)
    check_colnames (parsedata)
    check_select_tables (db_conn, None, parsedata)

    for node in parsedata.get_statements ():
        args = (node, parsedata, db_conn,
                real_client_ls, eff_client_ls, desired_ls, filters)

        if isinstance (node, CreateTableNode):
            handle_create (*args)
        elif isinstance (node, InsertNode):
            handle_insert (*args)
        elif isinstance (node, SelectNode):
            handle_select (*args)
        elif isinstance (node, UpdateNode):
            handle_update (*args)
        elif isinstance (node, DeleteNode):
            handle_delete (*args)
        elif isinstance (node, DropNode):
            handle_drop (*args)
        elif isinstance (node, CreateIndexNode):
            handle_create_index (*args)
        elif isinstance (node, SetNode):
            handle_set (*args)
        elif isinstance (node, ShowNode):
            handle_show (*args)
        elif isinstance (node, (BeginNode, CommitNode, AbortNode,
                                SpecialCaseNode, MyOLabelNode, DesLSNode,
                                FilterNode)):
            handle_ok (*args)
        else:
            raise DBV.SecurityViolation, 'Unsupported query type %s' % node.get_type ()


def check_label_statements (parsedata):
    # Check that any MYOLABEL and DESLS statements are at beginning of the
    # list, and that there is only one of each maximum.
    saw_non_ls = False
    saw = {}
    for node in parsedata.get_statements ():
        if saw_non_ls and node.get_type () in lab_statement_types:
            raise DBV.SecurityViolation, ('Types in %s must be the first statements in list' %
                                          (lab_statement_types,))

        if node.get_type () in lab_statement_types:
            if saw.has_key (node.get_type ()):
                raise DBV.SecurityViolation, "%s cannot appear more than once" % (node.get_type (),)
            saw[node.get_type ()] = node
        else:
            saw_non_ls = True

    if len (set(lab_statement_types).intersection (set(saw.keys()))) > 0 and not saw_non_ls:
        raise Exception, 'Must use MyOLabelNode with another SQL statement'

def get_cliolabel (parsedata):
    l = parsedata.get_nodes (MyOLabelNode)
    if len (l) > 0:
        return l[0].lab
    return None

def get_desired_ls (parsedata):
    l = parsedata.get_nodes (DesLSNode)
    if len (l) > 0:
        return l[0].ls
    return None

def get_verified_cli_olabel (parsedata, fd):
    import flume
    import flume.flmos as flmo

    olabel = get_cliolabel (parsedata)
    if not olabel:
        olabel = flmo.Label ()
    cos = flmo.CapabilityOpSet ([flmo.CapabilityOp (c, flume.CAPABILITY_VERIFY) for c in olabel])
    out = flmo.verify_capabilities (fd, 0, cos).toDict ()

    for cap in olabel:
        if out[cap] != flume.CAPABILITY_VERIFY:
            raise DBV.SecurityViolation, 'Could not verify capability %s' % (cap,)
    return olabel

class Filter (object):
    def __init__ (self, filename):
        self._handle = None
        self._token = None
        self._find = None
        self._repl = None
        self._valid = None
        self.read_file (filename)

    def __str__ (self):
        return '%s -> %s' % (self._find, self._repl)

    def read_file (self, filename):
        import flume
        import flume.flmos as flmo

        f = open (filename, 'r')
        dat = f.read ()
        f.close ()

        if (len (flmo.get_endpoint_info ()) > 10):
            # XXX Each time we open a filter, we accumulate another
            # endpoint.  The more endpoints we have, the slower DBV
            # gets.  We can fix this either by opening the file
            # directly (without going through flume), or by spawning a
            # helper which opens the file and then dies.
            raise OverflowError ("Too many endpoints!  Fix how we read filters!")

        for l in dat.splitlines ():
            k, v = l.split (None, 1)
            if k.lower () == 'handle':
                self._handle = flmo.Handle (v)
            elif k.lower () == 'token':
                self._token = v
            elif k.lower () == 'find':
                self._find = flmo.Handle (int (v, 16)).thaw ()
            elif k.lower () == 'replace':
                self._repl = flmo.Handle (int (v, 16)).thaw ()
            else:
                raise ValueError ("Unexpected key '%s' in filter file '%s'"
                                  % (k, filename))

    def adding (self):
        return self._repl - self._find

    def removing (self):
        return self._find - self._repl

    def find (self):
        return self._find

    def repl (self):
        return self._repl

    def is_valid (self):
        import flume
        import flume.flmos as flmo

        if self._valid:
            return self._valid

        allcaps = []
        for t in self.adding () + self.removing ():
            allcaps.extend (t.toCapabilities ())

        oldo = flmo.get_label (flume.LABEL_O)
        try:
            flmo.req_privs (self._handle, self._token)
            flmo.set_label2 (O=oldo + allcaps)
            return True

        except flume.LoginError:
            return False

        except flume.CapabilityError:
            return False

        finally:
            flmo.set_label2 (O=oldo)
                
def get_filter_filenames (parsedata):
    """ Returns the list of filenames that the user specified in
    FILTER statements"""
    import flume
    import flume.flmos as flmo

    filters = []
    for node in parsedata.get_nodes (FilterNode):
        filters.append (node.filename)
    return filters

filter_cache = {}
def add_new_filters (parsedata, filter_dict):
    for fn in get_filter_filenames (parsedata):
        if not filter_dict.has_key (fn):
            if filter_cache.has_key (fn):
                f = filter_cache[fn]
            else:
                f = Filter (fn)
                filter_cache[fn] = f
            if not f.is_valid ():
                raise DBV.SecurityViolation ('Filter %s is invalid' % fn)
            filter_dict[fn] = f
        
